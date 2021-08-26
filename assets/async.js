(function () {
    if (window.WebViewJavascriptBridge) {
        return;
    }

    class YGWebViewJavascriptBridge {
        constructor() {
            this.handlers = {};
            this.callbacks = {};
            this.index = 0;
            this.defaultHandler = null;
        }

        registerHandler(handlerName, handler) {
            this.handlers[handlerName] = handler;
        }

        async callHandler(handlerName, data) {
            if (arguments.length == 1) {
                data = null;
            }
            let result = await this.send(data, handlerName);
            return result;
        }

        async send(data, handlerName) {
            if (!data && !handlerName) {
                console.log('data and handlerName can not be null at the same in YGWebViewJavascriptBridge send method');
                alert('data and handlerName can not be null at the same in YGWebViewJavascriptBridge send method');
                return;
            }

            let message = {
                index: this.index,
                type: 'request',
            };
            if (data) {
                message.data = data;
            }
            if (handlerName) {
                message.handlerName = handlerName;
            }

            this._postMessage(message);
            let index = this.index;
            this.index += 1;
            return new Promise(resolve => this.callbacks[index] = resolve);
        }

        init(callback) {
            this.defaultHandler = callback;
        }

        _jsCallResponse(jsonData) {
            let index = jsonData.index;
            let callback = this.callbacks[index];
            delete this.callbacks[index];
            callback(jsonData.data);
        }

        _postMessage(jsonData) {
            let jsonStr = JSON.stringify(jsonData);
            let encodeStr = encodeURIComponent(jsonStr);
            YGFlutterJSBridgeChannel.postMessage(encodeStr);
        }

        nativeCall(message) {
            //here can't run immediately, wtf?
            setTimeout(() => this._nativeCall(message), 0);
        }

        async _nativeCall(message) {
            let decodeStr = decodeURIComponent(message);
            let jsonData = JSON.parse(decodeStr);

            if (jsonData.type === 'request') {
                if ('handlerName' in jsonData) {
                    let handler = this.handlers[jsonData.handlerName];
                    let data = await handler(jsonData.data);
                    this._nativeCallResponse(jsonData, data);
                } else {
                    let data = await this.defaultHandler(jsonData.data);
                    this._nativeCallResponse(jsonData, data);
                }
            } else if (jsonData.type === 'response') {
                this._jsCallResponse(jsonData);
            }
        }

        _nativeCallResponse(jsonData, response) {
            jsonData.data = response;
            jsonData.type = 'response';
            this._postMessage(jsonData);
        }
    }

    window.WebViewJavascriptBridge = new YGWebViewJavascriptBridge();

    setTimeout(() => {
        let doc = document;
        let readyEvent = doc.createEvent('Events');
        let jobs = window.WVJBCallbacks || [];
        readyEvent.initEvent('WebViewJavascriptBridgeReady');
        readyEvent.bridge = WebViewJavascriptBridge;
        delete window.WVJBCallbacks;
        for (let job of jobs) {
            job(WebViewJavascriptBridge);
        }
        doc.dispatchEvent(readyEvent);
    }, 0);
})();
