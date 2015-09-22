var $ = {
  docEl: document.documentElement,
  
  id: function(id) {
    return document.getElementById(id);
  },
  
  cls: function(klass, root) {
    return (root || document).getElementsByClassName(klass);
  },
  
  tag:  function(tag, root) {
    return (root || document).getElementsByTagName(tag);
  },
  
  qs: function(selector, root) {
    return (root || document).querySelector(selector);
  },

  qsa: function(selector, root) {
    return (root || document).querySelectorAll(selector);
  },
  
  on: function(o, e, h) {
    o.addEventListener(e, h, false);
  },
  
  off: function(o, e, h) {
    o.removeEventListener(e, h, false);
  },
  
  xhr: function(method, url, attrs, data, headers) {
    var h, key, xhr, form;
    
    xhr = new XMLHttpRequest();
    
    xhr.open(method, url, true);
    
    if (attrs) {
      for (key in attrs) {
        xhr[key] = attrs[key];
      }
    }
    
    if (headers) {
      for (h in headers) {
        xhr.setRequestHeader(h, headers[h]);
      }
    }
    
    if (data) {
      if (typeof data === 'string') {
        xhr.setRequestHeader('Content-type', 'application/x-www-form-urlencoded');
      }
      else {
        form = new FormData();
        for (key in data) {
          form.append(key, data[key]);
        }
        data = form;
      }
    }
    else {
      data = null;
    }
    
    xhr.send(data);
    
    return xhr;
  },
  
  postIdFromNode: function(el) {
    var root = $.docEl;
    
    while (el !== root) {
     if (el.classList.contains('post') || el.classList.contains('post-report')) {
        break;
      }
      
      el = el.parentNode;
    }
    
    if (el.id) {
      return el;
    }
    
    return null;
  },
  
  el: function(name) {
    return document.createElement(name);
  },
  
  frag: function() {
    return document.createDocumentFragment();
  },
  
  getItem: function(key) {
    return localStorage.getItem(key);
  },
  
  setItem: function(key, value) {
    return localStorage.setItem(key, value);
  },
  
  removeItem: function(key) {
    return localStorage.removeItem(key);
  },
  
  getCookie: function(name) {
    var i, c, ca, key;
    
    key = name + '=';
    ca = document.cookie.split(';');
    
    for (i = 0; c = ca[i]; ++i) {
      while (c.charAt(0) == ' ') {
        c = c.substring(1, c.length);
      }
      if (c.indexOf(key) === 0) {
        return decodeURIComponent(c.substring(key.length, c.length));
      }
    }
    
    return null;
  },
  
  setCookie: function(name, value, days, path, domain) {
    var date, vars = [];
    
    vars.push(name + '=' + value);
    
    if (days) {
      date = new Date();
      date = date.setTime(date.getTime() + (days * 86400000)).toGMTString();
      vars.push('expire=' + date);
    }
    
    if (path) {
      vars.push('path=' + domain);
    }
    
    if (domain) {
      vars.push('domain=' + domain);
    }
    
    document.cookie = vars.join('; ');
  },
  
  removeCookie: function(name, path, domain) {
    var vars = [];
    
    vars.push(name + '=');
    
    vars.push('expires=Thu, 01 Jan 1970 00:00:01 GMT');
    
    if (path) {
      vars.push('path=' + domain);
    }
    
    if (domain) {
      vars.push('domain=' + domain);
    }
    
    document.cookie = vars.join('; ');
  }
};

var ClickHandler = {
  commands: {},
  
  init: function() {
    $.on(document, 'click', this.onClick);
  },
  
  onClick: function(e) {
    var t, cmd, cb;
    
    t = e.target;
    
    if (t === document || !t.hasAttribute('data-cmd')) {
      return;
    }
    
    cmd = t.getAttribute('data-cmd');
    
    if (cmd && e.which === 1 && (cb = ClickHandler.commands[cmd])) {
      if (cb(t, e) !== false) {
        e.preventDefault();
      }
    }
  }
};

var Tip = {
  node: null,
  
  timeout: null,
  
  cbRoot: window,
  
  delay: 150,
  
  init: function() {
    document.addEventListener('mouseover', this.onMouseOver, false);
    document.addEventListener('mouseout', this.onMouseOut, false);
  },
  
  onMouseOver: function(e) {
    var cb, data, t;
    
    t = e.target;
    
    if (Tip.timeout) {
      clearTimeout(Tip.timeout);
      Tip.timeout = null;
    }
    
    if (t.hasAttribute('data-tip')) {
      data = t.getAttribute('data-tip');
      
      if (data[0] === '.') {
        cb = data.slice(1);
        
        if (!Tip.cbRoot[cb]) {
          return;
        }
        
        data = Tip.cbRoot[cb](t);
        
        if (data === false) {
          return;
        }
      }

      Tip.timeout = setTimeout(Tip.show, Tip.delay, t, data);
    }
  },
  
  onMouseOut: function(e) {
    if (Tip.timeout) {
      clearTimeout(Tip.timeout);
      Tip.timeout = null;
    }
    
    Tip.hide();
  },
  
  show: function(t, data) {
    var el, anchor, style, left, top, margin;
    
    margin = 4;
    
    el = document.createElement('div');
    el.id = 'tooltip';
    el.innerHTML = data;
    document.body.appendChild(el);
    
    anchor = t.getBoundingClientRect();
    
    top = anchor.top - el.offsetHeight - margin;
    
    if (top < 0) {
      top = anchor.top + anchor.height + margin;
    }
    
    left = anchor.left - (el.offsetWidth - anchor.width) / 2;
    
    if (left < 0) {
      left = margin;
    }
    else if (left + el.offsetWidth > $.docEl.clientWidth) {
      left = $.docEl - el.offsetWidth - margin;
    }
    
    style = el.style;
    style.display = 'none';
    style.top = (top + window.pageYOffset) + 'px';
    style.left = (left + window.pageXOffset) + 'px';
    style.display = '';
    
    Tip.node = el;
  },
  
  hide: function() {
    if (Tip.node) {
      document.body.removeChild(Tip.node);
      Tip.node = null;
    }
  }
};

Tip.init();
