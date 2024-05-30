An iOS only plugin for processing Apple Pay payments from your app.

### Installation:

For stable relases type:

```shell
cordova plugin add @bkamenov/cordova-plugin-apple-pay
```

For latest releases type:

```shell
cordova plugin add https://github.com/bkamenov/cordova-plugin-apple-pay
```

### Usage:

```js
// Check if Apple Pay is available
cordova.plugins.ApplePayPlugin.canMakePayment(
  {
    supportedNetworks: ["VISA", "MASTERCARD", "AMEX"],
    merchantCapabilities: ["3DS", "CREDIT_CARD", "DEBIT_CARD"],
  },
  function (response) {
    if (response.canMakePayments) {
      // Apple Pay is available, proceed with payment request
      var paymentRequest = {
        countryCode: "US",
        currencyCode: "USD",
        merchantIdentifier: "your_merchant_identifier",
        supportedNetworks: ["VISA", "MASTERCARD", "AMEX"],
        merchantCapabilities: ["3DS", "CREDIT_CARD", "DEBIT_CARD"],
        paymentSummaryItems: [
          { label: "Product", amount: "10.00" },
          { label: "Tax", amount: "1.00" },
          { label: "Shipping", amount: "5.00" },
        ],
      };

      cordova.plugins.ApplePayPlugin.requestPayment(
        paymentRequest,
        function (payment) {
          // Payment successful, handle payment object
          console.log("Payment successful:", payment);
        },
        function (error) {
          // Payment failed, handle error
          console.error("Payment failed:", error);
        }
      );
    } else {
      // Apple Pay is not available
      console.log("Apple Pay is not available on this device.");
    }
  },
  function (error) {
    // Error occurred while checking Apple Pay availability
    console.error("Error checking Apple Pay availability:", error);
  }
);
```
