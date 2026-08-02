module ApplicationHelper
  def social_icon_link(url, icon, label, link_class:, show_handle: false)
    return if url.blank?

    handle = show_handle ? social_handle_from_url(url) : nil

    link_to url,
            class: link_class,
            target: "_blank",
            rel: "noopener noreferrer",
            aria: { label: handle.present? ? "#{label} (#{handle})" : label } do
      concat render("shared/icons/#{icon}")
      concat tag.span(handle, class: "aa-social-handle") if handle.present?
    end
  end

  def social_handle_from_url(url)
    path = URI.parse(url).path.to_s.delete_prefix("/").split("/").reject(&:blank?).first
    return if path.blank?

    path.start_with?("@") ? path : "@#{path}"
  rescue URI::InvalidURIError
    nil
  end
end
