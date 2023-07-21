# frozen_string_literal: true

json.created_at stripe_card.created_at
json.id stripe_card.public_id
json.last4 stripe_card.last4 if stripe_card.user == @current_user
json.type stripe_card.card_type
json.status stripe_card.status_text.parameterize(separator: "_")
json.name stripe_card.name
json.organization do
  json.partial! stripe_card.event
end
json.user do
  json.partial! stripe_card.user
end
