# https://gist.github.com/jah2488/9216539
module Hiccup
  extend self

  def html(body)
    parse(body)
  end

  private

  def parse(body)
    if body.first.class != Symbol
      return nil if body.empty? || body.nil?
      return body.first,        parse(rest(body).flatten(1)) unless body.first.respond_to?(:each)
      return parse(body.first), parse(rest(body).flatten(1))
    else
      tag_tree(get_tag_name(body.first), *get_attrs_and_body(rest(body), parse_shorthand(body.first)))
    end
  end

  def tag_tree(name, attrs, body)
    if self_closing_tags.include?(name)
      tag(name, attrs).gsub('>', ' />')
    else
      [tag(name, attrs), body, "</#{name}>"].join
    end
  end

  def get_attrs_and_body(tail, shorthand)
    return to_attrs(tail.first.merge(shorthand)), parse(rest(tail)) if options_has_present?(tail)
    return to_attrs(shorthand),                   parse(tail)
  end

  def options_has_present?(tail)
    tail.first.respond_to?(:keys)
  end

  def get_tag_name(elem)
    elem.to_s.split(/[\.#]/).first
  end

  def tag(name, *attrs)
    "<#{name}#{attrs.join}>"
  end

  def parse_shorthand(tag)
    Shorthand[tag]
      .expand_class
      .expand_id
      .split(':')
      .drop(1)
      .each_slice(2)
      .inject({}) do |acc, (k,v)|
        acc.merge({k => v}) { |_,o,n| Array(o) << n }
      end
  end

  require 'delegate'
  class Shorthand < SimpleDelegator
    def self.[](str)
      new(str)
    end

    def initialize(str)
      @str = str.to_s
      super(@str)
    end

    def expand_class
      new @str.gsub('.',':class:')
    end

    def expand_id
      new @str.gsub('#',':id:')
    end

    def new(str)
      self.class.new(str)
    end

  end

  def rest(elem)
    elem.drop(1)
  end

  def to_attrs(hash)
    hash.map { |k, v| " #{k}=\"#{Array(v).join(' ')}\"" }
  end

  def self_closing_tags
    %w(area base br col colgroup command embed hr img input keygen link meta param source track wbr)
  end

end

# if $0 !~ /rspec/
#   begin require 'pry'; binding.pry rescue Gem::LoadError end
# else
#   new_lines_and_whitespace_not_in_a_tag = /\n\s+(?!\[^<>\]*)/
#   describe Hiccup do
#     context 'converts ruby syntax to html string' do
#       it { expect(Hiccup.html [:script]).to eq "<script></script>" }
#       it { expect(Hiccup.html [:p, "hello"]).to eq "<p>hello</p>" }
#       it { expect(Hiccup.html [:p, [:em, "hello"]]).to eq "<p><em>hello</em></p>" }
#       it { expect(Hiccup.html [:span, {:class => "foo"}, "bar"]).to eq "<span class=\"foo\">bar</span>" }
#       it { expect(Hiccup.html [:div, {id: "email", class: "selected starred"}, "..."]).to eq "<div id=\"email\" class=\"selected starred\">...</div>" }
#       it { expect(Hiccup.html [:a, {:href => "http://github.com"}, "GitHub"]).to eq "<a href=\"http://github.com\">GitHub</a>"}
#       context 'self closing tags' do
#         it { expect(Hiccup.html [:br]).to eq "<br />" }
#         it { expect(Hiccup.html [:link]).to eq "<link />" }
#         it { expect(Hiccup.html [:colgroup, {span: 2}]).to eq "<colgroup span=\"2\" />" }
#         it { expect(Hiccup.html [:div, [:p], [:br]]).to eq "<div><p></p><br /></div>" }
#       end
#       context 'collections' do
#         it { expect(Hiccup.html [:ul, ['a','b'].map { |x| [:li, x]}]).to eq "<ul><li>a</li><li>b</li></ul>"}
#         it { expect(Hiccup.html [:ul, (11...13).map { |n| [:li, n]}]).to eq "<ul><li>11</li><li>12</li></ul>"}
#       end
#       context 'css shorthand' do
#         it { expect(Hiccup.html [:'p.hi', "hello"]).to eq "<p class=\"hi\">hello</p>" }
#         it { expect(Hiccup.html [:'p#hi', "hello"]).to eq "<p id=\"hi\">hello</p>" }
#         it { expect(Hiccup.html [:'p.hi.greet.left', "hello"]).to eq "<p class=\"hi greet left\">hello</p>" }
#         it { expect(Hiccup.html [:'p#hi.greet.left', "hello"]).to eq "<p id=\"hi\" class=\"greet left\">hello</p>" }
#       end
#       context 'different shaped trees' do
#         it { expect(Hiccup.html [:p, "Hello ", [:em, "World!"]]).to eq "<p>Hello <em>World!</em></p>" }
#         it { expect(Hiccup.html [:div, [:p, "Hello"], [:em, "World!"]]).to eq "<div><p>Hello</p><em>World!</em></div>" }
#       end
#     end
#     it { expect(Hiccup.html [:html,
#                               [:head,
#                                 [:title, "Hello World"]],
#                               [:body,
#                                 [:header,
#                                   [:'h1.header', "Hello World"],
#                                     [:p, {id: 'why'}, "because we must."]]]]).to eq "
#                             <html>
#                               <head>
#                                 <title>Hello World</title>
#                               </head>
#                               <body>
#                                 <header>
#                                   <h1 class=\"header\">Hello World</h1>
#                                   <p id=\"why\">because we must.</p>
#                                 </header>
#                               </body>
#                             </html>".gsub(new_lines_and_whitespace_not_in_a_tag,'') }
#   end
# end
