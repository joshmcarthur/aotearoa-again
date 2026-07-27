module ApplicationHelper
  def social_nav_icon_link(url, icon_class, label)
    return if url.blank?

    link_to url,
            class: "aa-nav-icon",
            target: "_blank",
            rel: "noopener noreferrer",
            aria: { label: label } do
      tag.i class: "fa-brands #{icon_class}", aria: { hidden: true }
    end
  end
end
