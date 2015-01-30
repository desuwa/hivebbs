/**
 * quick and dirty proto
 */
$ = {
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
      if (data.constructor === Object) {
        form = new FormData();
        
        for (key in data) {
          form.append(key, data[key]);
        }
        
        data = form;
      }
    }
    else {
      data = null
    }
    
    xhr.send(data);
    
    return xhr;
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
      if (c.indexOf(key) == 0) {
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
      vars.push('path=' + domain)
    }
    
    if (domain) {
      vars.push('domain=' + domain)
    }
    
    document.cookie = vars.join('; ');
  },
  
  removeCookie: function(name, path, domain) {
    var vars = [];
    
    vars.push(name + '=');
    
    vars.push('expires=Thu, 01 Jan 1970 00:00:01 GMT');
    
    if (path) {
      vars.push('path=' + domain)
    }
    
    if (domain) {
      vars.push('domain=' + domain)
    }
    
    document.cookie = vars.join('; ');
  }
};

var QuotePreviews = {
  frozen: false,
  
  hasPreviews: false,
  
  timeout: null,
  
  delay: 75,
  
  init: function() {
    $.on(document, 'mouseover', QuotePreviews.onMouseOver);
  },
  
  onMouseOver: function(e) {
    var t = e.target;
    
    if (QuotePreviews.frozen) {
      if (t.classList.contains('quote-preview') || t.classList.contains('ql')) {
        QuotePreviews.frozen = false;
      }
      else {
        return;
      }
    }
    
    if (document.body.classList.contains('has-backdrop')) {
      QuotePreviews.frozen = true;
      return;
    }
    
    if (QuotePreviews.timeout) {
      clearTimeout(QuotePreviews.timeout);
      QuotePreviews.timeout = null;
    }
    
    if (t.classList.contains('ql')) {
      QuotePreviews.show(t);
    }
    else if (QuotePreviews.hasPreviews) {
      QuotePreviews.timeout =
        setTimeout(QuotePreviews.detach, QuotePreviews.delay, t);
    }
  },
  
  show: function(t) {
    var postId, postEl, el, cnt, aabb, s, left;
    
    postId = t.href.split('#').pop();
    postEl = $.id(postId);
    
    QuotePreviews.detach(t);
    
    if (!postEl || $.id('preview-' + postEl.id)) {
      return;
    }
    
    el = postEl.cloneNode(true);
    el.id = 'preview-' + el.id;
    
    cnt = $.el('div');
    cnt.className = 'quote-preview';
    cnt.appendChild(el);
    
    s = cnt.style;
    
    aabb = t.getBoundingClientRect();
    
    document.body.appendChild(cnt);
    
    if (aabb.right / $.docEl.clientWidth > 0.7) {
      s.maxWidth = (aabb.left - 20) + 'px';
      s.left = (aabb.left - cnt.offsetWidth - 5) + 'px';
    }
    else {
      s.maxWidth = ($.docEl.clientWidth - aabb.right - 20) + 'px';
      s.left = (aabb.right + window.pageXOffset + 5) + 'px';
    }
    
    s.top = (aabb.top + window.pageYOffset + 5) + 'px';
    
    QuotePreviews.hasPreviews = true;
  },
  
  detach: function(t) {
    var i, t, el, nodes, root;
    
    root = $.docEl;
    
    while (t !== root) {
     if (t.classList.contains('quote-preview')) {
        break;
      }
      
      t = t.parentNode;
    }
    
    nodes = $.cls('quote-preview');
    
    for (i = nodes.length - 1; i > -1; i--) {
      el = nodes[i];
      
      if (el === t) {
        break;
      }
      
      document.body.removeChild(el);
    }
    
    QuotePreviews.hasPreviews = !!nodes[0];
  }
};

var Hive = {
  clickCommands: null,
  
  init: function() {
    $.on(document, 'DOMContentLoaded', Hive.run);
    
    Hive.xhr = {};
    
    Hive.clickCommands = {
      'q': Hive.onPostNumClick,
      'fexp': Hive.onFileClick,
      'fcon': Hive.closeGallery,
      'markup': Hive.onMarkupClick,
      'captcha': Hive.onCaptchaClick,
      'tegaki': Hive.onTegakiClick
    };
    
    $.on(document, 'click', Hive.onClick);
    
    QuotePreviews.init();
  },
  
  run: function() {
    $.off(document, 'DOMContentLoaded', Hive.run);
    
    window.prettyPrint && window.prettyPrint();
  },
  
  onClick: function(e) {
    var t, cmd, cb;
    
    t = e.target;
    
    if (t === document) {
      return;
    }
    
    cmd = t.getAttribute('data-cmd');
    
    if (cmd && e.which === 1 && (cb = Hive.clickCommands[cmd])) {
      e.preventDefault();
      cb(t);
    }
  },
  
  onCaptchaClick: function(t) {
    var el = $.el('script');
    el.src = 'https://www.google.com/recaptcha/api.js';
    document.head.appendChild(el);
    t.classList.add('hidden');
  },
  
  abortXhr: function(id) {
    if (Hive.xhr[id]) {
      Hive.xhr[id].abort();
      delete Hive.xhr[id];
    }
  },
  
  onTegakiClick: function(t) {
    if (t.hasAttribute('data-active')) {
      Hive.closeTegaki(t);
    }
    else {
      Hive.showTegaki(t);
    }
  },
  
  showTegaki: function(t) {
    Tegaki.open({
      onDone: Hive.onTegakiDone,
      onCancel: Hive.onTegakiCancel,
      canvasOptions: Hive.buildTegakiCanvasList,
      width: +t.getAttribute('data-width'),
      height: +t.getAttribute('data-height')
    });
  },
  
  buildTegakiCanvasList: function(el) {
    var i, a, opt, nodes = $.cls('post-file-thumb');
    
    for (i = 0; a = nodes[i]; ++i) {
      if (/\.(png|jpg)$/.test(a.href)) {
        opt = $.el('option');
        opt.value = a.href;
        opt.textContent = '>>' + a.parentNode.parentNode.id;
        el.appendChild(opt);
      }
    }
  },
  
  onTegakiDone: function() {
    var input, data, thres, limit;
    
    input = $.id('tegaki-data');
    
    if (!input) {
      input = $.el('input');
      input.id = 'tegaki-data';
      input.name = 'tegaki';
      input.type = 'hidden';
      
      $.id('post-form').appendChild(input);
      
      $.id('file-field').classList.add('invisible');
      $.id('tegaki-btn').classList.add('tainted');
    }
    
    limit = +$.id('tegaki-btn').getAttribute('data-limit');
    thres = Tegaki.canvas.width * Tegaki.canvas.height;
    
    if (thres > limit) {
      data = Tegaki.flatten().toDataURL('image/jpeg', 0.9);
    }
    else {
      data = Tegaki.flatten().toDataURL('image/png');
    }
    
    if (data.length > limit) {
      alert('The resulting file size is too big.');
    }
    else {
      input.value = data;
    }
  },
  
  onTegakiCancel: function() {
    var input;
    
    if (input = $.id('tegaki-data')) {
      input.parentNode.removeChild(input);
      $.id('file-field').classList.remove('invisible');
      $.id('tegaki-btn').classList.remove('tainted');
    }
  },
  
  onFileClick: function(t) {
    var t, bg, el, href;
    
    bg = $.el('div');
    bg.id = 'backdrop';
    bg.setAttribute('data-cmd', 'fcon');
    
    href = t.parentNode.href;
    
    if (/\.webm$/.test(href)) {
      el = $.el('video');
      el.muted = true;
      el.controls = true;
      el.loop = true;
      el.autoplay = true;
      
      bg.innerHTML = '<div id="dummy-fcon" data-cmd="fcon"></div>';
    }
    else {
      el = $.el('img');
      el.alt = '';
      el.setAttribute('data-cmd', 'fcon');
    }
    
    el.id = 'expanded-file';
    el.className = 'fit-to-screen';
    el.src = href;
    
    bg.insertBefore(el, bg.firstElementChild);
    
    document.body.classList.add('has-backdrop');
    
    document.body.appendChild(bg);
  },
  
  closeGallery: function() {
    var el;
    
    if (el = $.id('backdrop')) {
      document.body.removeChild(el);
      document.body.classList.remove('has-backdrop');
    }
  },
  
  onMarkupClick: function(t) {
    if (t.hasAttribute('data-active')) {
      Hive.hideMarkupPreview(t);
    }
    else {
      Hive.showMarkupPreview(t);
    }
  },
  
  showMarkupPreview: function(t) {
    var el, com, data;
    
    Hive.abortXhr('markup');
    
    if (!(com = $.id('comment-field'))) {
      return;
    }
    
    t.setAttribute('data-active', '1');
    t.textContent = 'Loading…';
    
    data = new FormData();
    data.append('comment', com.value);
    
    Hive.xhr.markup = $.xhr('POST', '/markup', {
      onload: Hive.onMarkupLoaded
    }, data);
  },
  
  onMarkupLoaded: function() {
    var resp, el, com;
    
    Hive.xhr.markup = null;
    
    resp = JSON.parse(this.responseText);
    
    if (!(com = $.id('comment-field'))) {
      return;
    }
    
    if ((el = $.id('comment-preview'))) {
      el.parentNode.removeChild(el);
    }
    
    el = $.el('div');
    el.id = 'comment-preview';
    el.style.width = (com.offsetWidth - 2) + 'px';
    el.style.height = com.offsetHeight + 'px';
    
    el.innerHTML = resp.data;
    
    com.parentNode.appendChild(el);
    com.classList.add('hidden');
    
    $.id('comment-preview-btn').textContent = 'Write';
  },
  
  hideMarkupPreview: function(t) {
    var el, com;
    
    if (el = $.id('comment-preview')) {
      el.parentNode.removeChild(el);
    }
    
    if (com = $.id('comment-field')) {
      com.classList.remove('hidden');
    }
    
    t.removeAttribute('data-active');
    t.textContent = 'Preview';
  },
  
  onPostNumClick: function(t) {
    Hive.quotePost(+t.textContent);
  },
  
  quotePost: function(postId) {
    var txt, pos, sel, com;
    
    com = $.id('comment-field');
    
    pos = com.selectionStart;
    
    sel = window.getSelection().toString();
    
    if (postId) {
      txt = '>>' + postId + '\n';
    }
    else {
      txt = '';
    }
    
    if (sel) {
      txt += '>' + sel.trim().replace(/[\r\n]+/g, '\n>') + '\n';
    }
    
    if (com.value) {
      com.value = com.value.slice(0, pos)
        + txt + com.value.slice(com.selectionEnd);
    }
    else {
      com.value = txt;
    }
    
    com.selectionStart = com.selectionEnd = pos + txt.length;
    
    if (com.selectionStart == com.value.length) {
      com.scrollTop = com.scrollHeight;
    }
    
    com.focus();
  }
};

Hive.init();
