Rack::Attack.throttle("api/req/token", limit: 300, period: 5.minutes) do |req|
  if req.path.start_with?("/api/v1/")
    token = req.get_header("HTTP_AUTHORIZATION")&.delete_prefix("Bearer ")
    Digest::SHA256.hexdigest(token) if token.present?
  end
end
