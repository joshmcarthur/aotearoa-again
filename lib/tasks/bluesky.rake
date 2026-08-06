namespace :bluesky do
  desc "Create the one-off site.standard.publication record and print credentials to add"
  task bootstrap_publication: :environment do
    ref = StandardSite::PublicationBootstrap.call
    puts "Add to credentials under bluesky:"
    puts "  publication_uri: #{ref[:uri]}"
    puts "  publication_cid: #{ref[:cid]}"
  end
end
