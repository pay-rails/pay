import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="lemon-squeezy"
export default class extends Controller {
  static targets = ["redirectUrl", "storeId", "variantId"]

  submit(event) {
    event.preventDefault()

    // Collect form data
    const data = {
      data: {
        attributes: {
          redirect_url: this.redirectUrlTarget.value
        },
        relationships: {
          store: {
            data: {
              type: "stores",
              id: this.storeIdTarget.value
            }
          },
          variant: {
            data: {
              type: "variants",
              id: this.variantIdTarget.value
            }
          }
        }
      }
    }

    // Send data to Rails backend
    fetch('/lemon_squeezy/subscriptions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(data)
    })
    .then(response => response.json())
    .then(result => {
      if (result.error) {
        alert(`Error: ${result.error}`)
      } else {
        // Redirect or display a message to the user
        window.location.href = result.url
      }
    })
    .catch(error => {
      console.error('Error:', error)
    })
  }

  // Helper function to get meta tag value
  getMetaValue(name) {
    const element = document.querySelector(`meta[name="${name}"]`)
    return element ? element.getAttribute('content') : null
  }
}
