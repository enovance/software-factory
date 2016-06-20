
function isCookiesEnabled() {
    var isEnabled = (navigator.cookieEnabled) ? true : false;
    if ( typeof navigator.cookieEnabled == "undefined" && !cookieEnabled ) {
        document.cookie='test';
        isEnabled = (document.cookie.indexOf('test')!=1) ? true : false;
    }
    return isEnabled;
}

function getValueOfKey(target, key) {
    var tokens = target.split(/%3B/); // semi-colon
    for ( var i = 0; i < tokens.length; i++ ) {
        var keyvalue = tokens[i].split(/%3D/);
        if ( key.indexOf(keyvalue[0]) == 0 ) {
            return keyvalue[1];
        }
    }
    return false;
}

function displayLoggedIn(username) {
    try {
        document.getElementById("login-msg").innerHTML = "Welcome " + username;
        document.getElementById("login-msg").style.display = "block";
        document.getElementById("login-btn").style.display = "none";
        document.getElementById("logout-btn").style.display = "block";
    } catch (err) {
    }
}

function displaySignIn() {
    try {
        document.getElementById("login-msg").innerText = "";
        document.getElementById("login-msg").style.display = "none";
        document.getElementById("login-btn").style.display = "block";
        document.getElementById("logout-btn").style.display = "none";
    } catch (err) {
    }
}

function initAuth() {
    if ( isCookiesEnabled() ) {
        var tokens = document.cookie.split(';');
        for ( var i = 0; i < tokens.length; i++ ) {
            tokens[i] = tokens[i].trim();
            if ( tokens[i].indexOf('auth_pubtkt') == 0 ) {
                var username = getValueOfKey(tokens[i].substring(12), 'uid');
                if ( username ) {
                    /* Storyboard localstorage setting */
                    /* TODO: replace hardcoded value bellow by dynamic values */
                    var token = "42424242" //getValueOfKey(tokens[i], 'sig').substring(100);
                    var storyboard_user_id = "1"
                    //alert(tokens[i]);
                    localStorage.setItem("ls.access_token", token);
                    localStorage.setItem("ls.id_token", storyboard_user_id);
                    localStorage.setItem("ls.token_type", "Bearer");
                    displayLoggedIn(username);
                    return;
                }
            }
        }
    }
    displaySignIn();
};

/** Init function 
 */
if (document.body) {
    initAuth();
} else {
    document.onload = function() {initAuth();};
}
