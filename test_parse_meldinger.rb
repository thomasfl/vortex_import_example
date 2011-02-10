require 'rubygems'
require 'test/unit'
require 'shoulda'
$LOAD_PATH.unshift File.expand_path(File.join(File.dirname(__FILE__), "..", "src"))
require 'msg_parser'

class TestParseMeldindger < Test::Unit::TestCase

  should "parse a message" do
    destination = "https://nyweb5-dav.uio.no/konv/ifi-meldinger/"
    msgParser = MsgParser.new(destination)
    url = "http://www.ifi.uio.no/migrering/meldinger/seminars/3327.html"
    message = msgParser.parse_msg(url)
    assert (message[:title] =~ /^Faggruppe/)
    assert message[:published]
    assert (message[:introduction] =~ /^Faggruppe/)
    assert message[:body]
  end

  should "crawl messages" do
    destination = "https://nyweb5-dav.uio.no/konv/ifi-meldinger/"
    msgParser = MsgParser.new(destination)
    url = "http://www.ifi.uio.no/migrering/meldinger/"
    result = msgParser.crawler(url)
    assert result.size > 30
  end

  should "publish an article" do
    destination = "https://nyweb5-dav.uio.no/konv/ifi-meldinger/"
    msgParser = MsgParser.new(destination)
    src = "http://www.ifi.uio.no/migrering/meldinger/seminars/3327.html"
    msgParser.migrate_article(src,destination)
  end

end
