import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="lemon-squeezy"
export default class extends Controller {
  connect() {
    window.createLemonSqueezy()

    LemonSqueezy.Setup({
      eventHandler: (event) => {
        if (event.event === "Checkout.Success") {
          const data = {
            processor: 'lemon_squeezy', // Assuming 'lemon_squeezy' is the processor name
            customer_id: event.data.order.data.attributes.customer_id,
            name: 'default',
            processor_id: event.data.order.data.attributes.first_order_item.order_id,
            processor_plan: 'default',
            status: 'active',
            plan_id: event.data.order.data.attributes.first_order_item.variant_id, // assuming variant_id is the plan ID
            card_token: event.data.order.data.attributes.card_token // assuming card_token is available
          }

          fetch('/lemon_squeezy/subscriptions', {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json'
            },
            body: JSON.stringify(data)
          })
          .then(response => {
            if (!response.ok) {
              return response.json().then(err => {
                throw new Error(err.error || 'Unknown error')
              })
            }
            return response.json()
          })
          .then(result => {
            if (result.error) {
              alert(`Error: ${result.error}`)
            } else {
              window.location.href = '/lemon_squeezy/subscriptions'
            }
          })
          .catch(error => {
            console.error('Error:', error)
          })
        }
      }
    })
  }
}
