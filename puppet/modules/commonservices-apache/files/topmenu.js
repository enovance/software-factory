function loadTopmenu() {
        var iframe = document.createElement("iframe");
        iframe.setAttribute("src", "/topmenu.html");
        iframe.setAttribute("width", "100%");
        iframe.setAttribute("height", "51px");
        iframe.frameBorder = 0;
        document.body.insertBefore(iframe, document.body.firstChild);
        document.title += ' [SF 0.9.8]';
};

if (document.body) {
    loadTopmenu();
} else {
    window.onload = function() {loadTopmenu();};
};
