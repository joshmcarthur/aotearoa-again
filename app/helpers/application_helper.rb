module ApplicationHelper
  def social_icon_link(url, icon, label, link_class:)
    return if url.blank?

    link_to url,
            class: link_class,
            target: "_blank",
            rel: "noopener noreferrer",
            aria: { label: label } do
      render("shared/icons/#{icon}")
    end
  end
end
