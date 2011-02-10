require 'rubygems'
require 'nokogiri'
require 'open-uri'
require 'date'
require 'vortex_client'
require 'uri'
require 'pathname'
require 'htmlentities'

class MsgParser

  attr :vortex, :coder

  def initialize(destination_url)
    @vortex = Vortex::Connection.new(destination_url)
    @coder = HTMLEntities.new
  end

  def migrate_article(src_url, destination_url)
    uri = URI.parse(src_url)

    destination_path = URI.parse(destination_url).path
    uri.path().split(/\//).each do |folder|
      if(folder and folder != "" and not(folder =~ /.html$/))
        destination_path = destination_path + folder + "/"

        if( not(@vortex.exists?(destination_path)))
          puts "Creating directory: " + destination_path
          @vortex.mkdir(destination_path)
          @vortex.proppatch(destination_path,
                          "<v:resourceType xmlns:v=\"vrtx\">article-listing</v:resourceType>" +
                          "<v:collection-type xmlns:v=\"vrtx\">article-listing</v:collection-type>")
        end
      end
    end

    message = parse_msg(src_url)
    destination_path = destination_path + message[:filename]
    count = 0
    while(@vortex.exists?(destination_path))do
      puts "Warning: filename exists: " + destination_path
      count = count + 1
      destination_path = destination_path.sub(/\.html$/, "-" + count.to_s + ".html")
    end

    article  = Vortex::StructuredArticle.new(:title => message[:title],
                           :url => destination_path,
                           :introduction => message[:introduction],
                           :body => message[:body],
                           :publishedDate => message[:published],
                           :author => "Kristin Skar")
    path = vortex.publish(article)
    @vortex.proppatch(path, '<v:publish-date xmlns:v="vrtx">' +
                      message[:published].httpdate.to_s + '</v:publish-date>')
    puts "Published:" + path
  end

  def parse_msg(url)
    msg = { }
    doc = Nokogiri::HTML.parse(open(url))
    msg[:title] = doc.xpath("//div[@id='overskrift']/p").
      inner_html.sub('<b>Overskrift:</b>','').strip
    msg[:title] = @coder.decode(msg[:title]).strip
    published = doc.xpath("//div[@id='tidspunkt_publisert']").
      inner_html.sub('<b>Tidspunkt publisert:</b>','').strip
    published_date = DateTime.strptime(published, '%d.%m.%Y.%H.%M.%S')
    msg[:published] = Time.parse(published_date.to_s)
    msg[:introduction] = doc.xpath("//div[@id='ingress']/p").
      inner_html.sub('<b>Ingress:</b>','').strip
    msg[:body] = doc.xpath("//div[@id='innhold']/p").
      inner_html.sub('<b>Innhold:</b>','').strip
    msg[:filename] = Vortex::StringUtils.create_filename(msg[:title]) + ".html"
    return msg
  end

  # Return a list of all documents found, recursively.
  def crawler(url)
    result = []
    doc = Nokogiri::HTML.parse(open(url))
    row = doc.xpath("//tr[4]").first
    while(row)do
      row_doc = Nokogiri::HTML(row.to_s)
      link = row_doc.xpath("//a").first
      if(link)then
        href = url + link.attribute("href").value
        if(href =~ /\/$/)then
          result = result + crawler(href)
        else
          result << href
        end
      end
      row = row.next
    end
    return result
  end

end

if __FILE__ == $0 then

  destination = "https://nyweb5-dav.uio.no/konv/ifi-meldinger/"
  msgParser = MsgParser.new(destination)
  url = "http://www.ifi.uio.no/migrering/meldinger/"
  msgParser.crawler(url).each do |message|
    msgParser.migrate_article(message,destination)
  end

end
