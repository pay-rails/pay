# Webhooks

In order for Pay to automatically sync charges and subscriptions, Lago must be configured to point to Pay's Lago endpoint.

## Adding the Webhook to Lago
You can add webhooks using the [Lago UI](https://docs.getlago.com/guide/webhooks). Pay's default webhook endpoint for Lago
is `/pay/webhooks/lago` (`/pay` is replaced by the mountpoint of the Pay engine). Webhooks should use JWT.

Alternatively you can use the helper method to add the webhook to Lago.

```ruby
# Create a webhook endpoint in Lago for the Pay gem.
Pay::Lago.create_webhook!("https://mypayinstance.example")
```

```ruby
# Create a webhook endpoint, where you have mounted Pay at a different path (eg. "admin/pay").
# Not necessary unless you have disabled "automount_routes".
Pay::Lago.create_webhook!("https://mypayinstance.example", "/admin/pay")
```

Please note: the given string must be a valid HTTP/S URL. Pay will automatically set the path of the URL to be the correct path,
so you only need to provide the root URL.

## List of Events Pay Implements

Pay doesn't listen to every event, because not all are relevant to the operation of the gem. You can find a full list
of events [here](https://docs.getlago.com/api-reference/webhooks/messages).

### Customer Payment Provider Created
`customer.payment_provider_created`

When this event is triggered, Pay updates the respective Pay::Customer with the new payment provider information.

### Invoice Created
`invoice.created`

When this event is triggered, Pay creates or updates a Pay::Charge for the given Invoice, and sends a reciept if so configured.

### Invoice Drafted
`invoice.drafted`

When this event is triggered, Pay creates or updates a Pay::Charge for the given Invoice, but doesn't send a reciept.

### Invoice One Off Created
`invoice.one_off_created`

Currently handles the same as [Invoice Created](#invoice-created).

### Invoice Payment Status Updated
`invoice.payment_status_updated`

When this event is triggered, it will update the payment status in the corresponding charge's data.

Does nothing if no matching charge is found.

### Subscription Started
`subscription.started`

Creates or updates a Pay::Subscription with the recieved information.

### Subscription Terminated
`subscription.terminated`

Currently handles the same as [Subscription Started](#subscription-started). However, the information provided by Lago will
cause the subscription to be considered terminated.