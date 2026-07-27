module ApplicationHelper
  def social_nav_icon_link(url, icon, label)
    return if url.blank?

    link_to url,
            class: "aa-nav-icon",
            target: "_blank",
            rel: "noopener noreferrer",
            aria: { label: label } do
      render("shared/icons/#{icon}")
    end
  end
end
