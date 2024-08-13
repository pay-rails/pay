# Stripe JavaScript

Here's some example Javascript for handling your payment forms with [Stripe.js](https://docs.stripe.com/js) and [Hotwire / Turbo](https://hotwired.dev).

#### Form HTML

With SCA, each of your actions client-side need a PaymentIntent or SetupIntent ID depending on what you're doing. If you're charging a card immediately, you must provide a PaymentIntent ID. For trials or updating the card on file, you should use a SetupIntent ID.

We recommend setting these IDs as data attributes on your `form`.

You can use  `data-payment-intent` or `data-setup-intent` depending on if you're making a payment (PaymentIntent) or setting up a card to use later (SetupIntent).

```rb
# Your controller if you are using a SetupIntent:

def new
  ...
  @setup_intent = current_user.payment_processor.create_setup_intent
  ...
end
```

```erb
<%= form_with url: subscription_path,
  id: "payment-form",
  data: {
    payment_intent: @payment_intent,
    setup_intent: @setup_intent.client_secret
  } do |form| %>

  <label>Credit or debit card</label>
  <div id="card-element" class="field"></div>

  <%= form.submit %>
<% end %>
```

Make sure any payment forms have `id="payment-form"` on them. This is how the Javascript finds the form to add Stripe to it.

Card fields should have an ID of `id="card-element"` to denote trigger Stripe JS to be applied to the form.

#### Stripe Public Key

A meta tag with `name="stripe-key"` should include the Stripe public key as the `content` attribute.

```erb
<%= tag.meta name: "stripe-key", content: Pay::Stripe.public_key %>
<script src="https://js.stripe.com/v3/" defer></script>
```

#### Javascript

When a form is submitted, the card will be tokenized into a Payment Method ID and submitted as a hidden field in the form.

```javascript
document.addEventListener("turbo:load", () => {
  let cardElement = document.querySelector("#card-element")

  if (cardElement !== null) { setupStripe() }

  // Handle users with existing card who would like to use a new one
  let newCard = document.querySelector("#use-new-card")
  if (newCard !== null) {
    newCard.addEventListener("click", (event) => {
      event.preventDefault()
      document.querySelector("#payment-form").classList.remove("d-none")
      document.querySelector("#existing-card").classList.add("d-none")
    })
  }
})

function setupStripe() {
  const stripe_key = document.querySelector("meta[name='stripe-key']").getAttribute("content")
  const stripe = Stripe(stripe_key)

  const elements = stripe.elements()
  const card = elements.create('card')
  card.mount('#card-element')

  var displayError = document.getElementById('card-errors')

  card.addEventListener('change', (event) => {
    if (event.error) {
      displayError.textContent = event.error.message
    } else {
      displayError.textContent = ''
    }
  })

  const form = document.querySelector("#payment-form")
  let paymentIntentId = form.dataset.paymentIntent
  let setupIntentId = form.dataset.setupIntent

  if (paymentIntentId) {
    if (form.dataset.status == "requires_action") {
      stripe.confirmCardPayment(paymentIntentId, { setup_future_usage: 'off_session' }).then((result) => {
        if (result.error) {
          displayError.textContent = result.error.message
          form.querySelector("#card-details").classList.remove("d-none")
        } else {
          form.submit()
        }
      })
    }
  }

  form.addEventListener('submit', (event) => {
    event.preventDefault()

    let name = form.querySelector("#name_on_card").value
    let data = {
      payment_method_data: {
        card: card,
        billing_details: {
          name: name,
        }
      }
    }

    // Complete a payment intent
    if (paymentIntentId) {
      stripe.confirmCardPayment(paymentIntentId, {
        payment_method: data.payment_method_data,
        setup_future_usage: 'off_session',
        save_payment_method: true,
      }).then((result) => {
        if (result.error) {
          displayError.textContent = result.error.message
          form.querySelector("#card-details").classList.remove("d-none")
        } else {
          form.submit()
        }
      })

    // Updating a card or subscribing with a trial (using a SetupIntent)
    } else if (setupIntentId) {
      stripe.confirmCardSetup(setupIntentId, {
        payment_method: data.payment_method_data
      }).then((result) => {
        if (result.error) {
          displayError.textContent = result.error.message
        } else {
          addHiddenField(form, "payment_method_token", result.setupIntent.payment_method)
          form.submit()
        }
      })

    } else {
      // Subscribing with no trial
      data.payment_method_data.type = 'card'
      stripe.createPaymentMethod(data.payment_method_data).then((result) => {
        if (result.error) {
          displayError.textContent = result.error.message
        } else {
          addHiddenField(form, "payment_method_token", result.paymentMethod.id)
          form.submit()
        }
      })
    }
  })
}

function addHiddenField(form, name, value) {
  let input = document.createElement("input")
  input.setAttribute("type", "hidden")
  input.setAttribute("name", name)
  input.setAttribute("value", value)
  form.appendChild(input)
}
```

## Next

See [Strong Customer Authentication (SCA)](4_sca.md)
