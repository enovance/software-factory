
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
                    displayLoggedIn(username);
                    return;
                }
            }
        }
    }
    displaySignIn();
};

function toggle_visibility(id) {
  var e = document.getElementById(id);
  if(e.style.display == 'block')
    e.style.display = 'none';
  else
    e.style.display = 'block';
};

function closeNavbar() {
  document.getElementById("navbar-workflow").style.display = "none";
  document.getElementById("navbar-collaboration").style.display = "none";
};

function initTopMenu() {
  closeNavbar();
  document.getElementById("navbar-workflow-btn").onclick = function(event) {
    toggle_visibility("navbar-workflow");
    event.stopPropagation();
  };
  document.getElementById("navbar-collaboration-btn").onclick = function(event) {
    toggle_visibility("navbar-collaboration");
    event.stopPropagation();
  };
  var btns = document.getElementsByClassName("close-navbar");
  for (var i=0; i<btns.length; i++){
    btns[i].onclick = function(event) {
      closeNavbar();
      event.stopPropagation();
    }
  }
};
 
/** Init function 
 */
if (document.body) {
  initAuth();
  initTopMenu();
} else {
  document.onload = function() {
    initAuth();
    initTopMenu();
  };
}
