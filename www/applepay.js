var exec = require('cordova/exec');

var ApplePayPlugin = {
    canMakePayment: function (options, successCallback, errorCallback) {
        exec(successCallback, errorCallback, 'ApplePayPlugin', 'canMakePayment', [options]);
    },
    requestPayment: function (paymentData, successCallback, errorCallback) {
        exec(successCallback, errorCallback, 'ApplePayPlugin', 'requestPayment', [paymentData]);
    }
};

module.exports = ApplePayPlugin;
