MICRO = {
  "tag_sym" => -> { v = ApplicationController.new.view_context; -> { v.tag.a("x", href: "/p", class: "c", data: { id: 1 }) } },
  "tag_str" => -> { v = ApplicationController.new.view_context; -> { v.content_tag(:a, "x", "href" => "/p", "class" => "c", "data" => { "id" => 1 }) } },
  "link_to" => -> { v = ApplicationController.new.view_context; -> { v.link_to("x", "/posts", class: "c") } },
}
