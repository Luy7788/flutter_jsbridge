(function () {
    if (window.flutterJsBridge) {
        return;
    }

    window.flutterJsBridge = {
        handlers: {},
        callbacks: {},
        index: 0,
        defaultHandler: null,

        registerHandler: _registerHandler,
        callHandler: _callHandler,
        init: _init,
        send: _send,
        nativeCall: _nativeCall,
    };


    function _registerHandler(handlerName, handler) {
        flutterJsBridge.handlers[handlerName] = handler;
    }

    function _callHandler(handlerName, data, callback) {
        if (arguments.length == 2 && typeof data == 'function') {
            callback = data;
            data = null;
        }
        _send(data, callback, handlerName);
    }

    function _init(callback) {
        flutterJsBridge.defaultHandler = callback;
    }

    function _send(data, callback, handlerName) {
        if (!data && !handlerName) {
            console.log('flutterJsBridge: data and handlerName can not both be null at the same in flutterJsBridge send method');
            return;
        }

        var index = flutterJsBridge.index;

        var message = {
            index: index,
            type: 'request',
        };
        if (data) {
            message.data = data;
        }
        if (handlerName) {
            message.handlerName = handlerName;
        }

        flutterJsBridge.callbacks[index] = callback;
        flutterJsBridge.index += 1;

        _postMessage(message, callback);
    }


    function _jsCallResponse(jsonData) {
        var index = jsonData.index;
        var callback = flutterJsBridge.callbacks[index];
        delete flutterJsBridge.callbacks[index];
        if (jsonData.type === 'response') {
            callback(jsonData.data);
        } else {
            console.log('HXWebViewJavascriptBridge: js call native error for request ', JSON.stringify(jsonData));
        }
    }

    function _postMessage(jsonData) {
        var jsonStr = JSON.stringify(jsonData);
        var encodeStr = encodeURIComponent(jsonStr);
        HXFlutterJSBridgeChannel.postMessage(encodeStr);
    }

    function _nativeCall(message) {
        //here can't run immediately, wtf?
        setTimeout(() => _nativeCall(message), 0);
    }

    function _nativeCall(message) {
        var decodeStr = decodeURIComponent(message);
        var jsonData = JSON.parse(decodeStr);

        if (jsonData.type === 'request') {
            if ('handlerName' in jsonData) {
                var handlerName = jsonData.handlerName;
                if (handlerName in flutterJsBridge.handlers) {
                    var handler = flutterJsBridge.handlers[jsonData.handlerName];
                    handler(jsonData.data, function (data) {
                        _nativeCallResponse(jsonData, data);
                    });
                } else {
                    _nativeCallError(jsonData);
                    console.log('flutterJsBridge: no handler for native call ', handlerName);
                }

            } else {
                if (flutterJsBridge.defaultHandler) {
                    flutterJsBridge.defaultHandler(jsonData.data, function (data) {
                        _nativeCallResponse(jsonData, data);
                    });
                } else {
                    _nativeCallError(jsonData);
                    console.log('flutterJsBridge: no handler for native send');
                }
            }
        } else if (jsonData.type === 'response' || jsonData.type === 'error') {
            _jsCallResponse(jsonData);
        }
    }

    function _nativeCallError(jsonData) {
        jsonData.type = 'error';
        _postMessage(jsonData);
    }

    function _nativeCallResponse(jsonData, response) {
        jsonData.type = 'response';
        jsonData.data = response;
        _postMessage(jsonData);
    }

    setTimeout(() => {
        var doc = document;
        var readyEvent = doc.createEvent('Events');
        var jobs = window.WVJBCallbacks || [];
        readyEvent.initEvent('flutterJsBridgeReady');
        readyEvent.bridge = flutterJsBridge;
        delete window.WVJBCallbacks;
        for (var i = 0; i < jobs.length; i++) {
            var job = jobs[i];
            job(flutterJsBridge);
        }
        doc.dispatchEvent(readyEvent);
    }, 0);
})();
