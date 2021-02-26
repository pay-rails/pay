import { Controller } from "stimulus"
import Rails from "@rails/ujs"

export default class extends Controller {
  static targets = [ "dropin", "form" ]

  connect() {
    braintree.dropin.create({
      authorization: this.data.get("clientToken"),
      container: this.dropinTarget,
      //threeDSecure: true,
      paypal: {
        flow: "vault"
      },
      // Uncomment this to only display PayPal in the Drop-in UI
      //paymentOptionPriority: ['paypal']
    },
      this.clientCreated.bind(this)
    )
  }

  clientCreated(error, instance) {
    if (error) {
      console.error("Error setting up Braintree dropin:", error)
      return
    }

    this.instance = instance
  }

  submit(event) {
    event.preventDefault()
    this.instance.requestPaymentMethod(this.paymentMethod.bind(this))
  }

  paymentMethod(error, payload) {
    if (error) {
      console.error("Error with payment method:", error)
      return
    }

    this.addHiddenField("processor", "braintree")
    this.addHiddenField("card_token", payload.nonce)

    Rails.fire(this.formTarget, "submit")
  }

  addHiddenField(name, value) {
    let hiddenInput = document.createElement("input")
    hiddenInput.setAttribute("type", "hidden")
    hiddenInput.setAttribute("name", name)
    hiddenInput.setAttribute("value", value)
    this.formTarget.appendChild(hiddenInput)
  }
}
