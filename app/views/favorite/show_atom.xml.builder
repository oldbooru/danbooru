xml.instruct!

xml.feed("xmlns" => "http://www.w3.org/2005/Atom") do
	xml.title("#{CONFIG['app_name']}: Favorite posts for #{@user.pretty_name}")
	xml.link("rel" => "self", "href" => url_for(:only_path => false, :controller => "user", :action => "favorites_atom"))
	xml.link("rel" => "alternate", "href" => url_for(:only_path => false, :controller => "user", :action => "favorites"))
	xml.id(url_for(:only_path => false, :controller => "user", :action => "favorites_atom"))
	xml.updated(@posts.first.created_at.gmtime.xmlschema) if @posts.any?
	xml.author { xml.name "#{CONFIG['app_name']} project" }

	@posts.each do |post|
		xml.entry do
			xml.title(post.cached_tags)
			xml.link("rel" => "alternate", "href" => url_for(:only_path => false, :controller => "post", :action => "show", :id => post.id))
			if post.source=~/^http/
				xml.link("rel" => "related", "href" => post.source.gsub("&", "&amp;"))
			end
			xml.id(url_for(:only_path => false, :controller => "post", :action => "show", :id => post.id))
			xml.updated(post.created_at.gmtime.xmlschema)
			xml.author { xml.name h(post.author) }
			xml.summary(post.cached_tags)
			xml.content("type" => "xhtml") do
				xml.div("xmlns" => "http://www.w3.org/1999/xhtml") do
					xml.a("href" => url_for(:only_path => false, :controller => "post", :action => "show", :id => post.id)) do
						xml.img("src" => post.preview_url)
					end
				end
			end
		end
	end
end