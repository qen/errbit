Fabricator :notification_service  do
  app!
  room_id { Fabricate.sequence :word }
  api_token { Fabricate.sequence :word }
  subdomain { Fabricate.sequence :word }
end

Fabricator :gtalk_notification_service, :from => :notification_service, :class_name => "NotificationService::GtalkService" do
  user_id { sequence :word }
  service_url { sequence :word }
  service { sequence :word }
end

%w(campfire hipchat hoiio pushover hubot webhook).each do |t|
  Fabricator "#{t}_notification_service".to_sym, :from => :notification_service, :class_name => "NotificationService::#{t.camelcase}Service"
end
