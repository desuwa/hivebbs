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
    var i, el, nodes, root;
    
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
  xhr: {},
  
  init: function() {
    $.on(document, 'DOMContentLoaded', Hive.run);
    
    ClickHandler.commands = {
      'q': Hive.onPostNumClick,
      'fexp': Hive.onFileClick,
      'fcon': Hive.closeGallery,
      'markup': Hive.onMarkupClick,
      'captcha': Hive.onDisplayCaptchaClick,
      'tegaki': Hive.onTegakiClick,
      'post-menu': Hive.onReportClick, // do the actual post menu some day
      'delete-post': Hive.onDeletePostClick,
      'pin-thread': Hive.onPinThreadClick,
      'lock-thread': Hive.onLockThreadClick
    };
    
    ClickHandler.init();
    QuotePreviews.init();
  },
  
  run: function() {
    var page;
    
    $.off(document, 'DOMContentLoaded', Hive.run);
    
    page = document.body.getAttribute('data-page');
    
    if (page === 'read') {
      if ($.getCookie('csrf')) {
        Hive.addManagerControls();
      }
    }
    else if (page === 'report') {
      Hive.loadReCaptcha();
    }
    
    window.prettyPrint && window.prettyPrint();
  },
  
  onReportClick: function(t) {
    var params, src;
    params = location.pathname.split('/');
    src = '/report/' + params[1] + '/' + params[3] + '/' + t.parentNode.parentNode.id;
    window.open(src);
  },
  
  onDisplayCaptchaClick: function(t) {
    Hive.loadReCaptcha();
    t.classList.add('hidden');
  },
  
  loadReCaptcha: function() {
    var el = $.el('script');
    el.src = 'https://www.google.com/recaptcha/api.js';
    document.head.appendChild(el);
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
    var bg, el, href;
    
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
    var el, com;
    
    Hive.abortXhr('markup');
    
    if (!(com = $.id('comment-field'))) {
      return;
    }
    
    t.setAttribute('data-active', '1');
    t.textContent = 'Loading…';
    
    Hive.xhr.markup = $.xhr('POST', '/markup',
      {
        onload: Hive.onMarkupLoaded
      },
      {
        comment: com.value
      }
    );
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
  },
  
  onPostDeleted: function() {
    var el = $.id(this.hivePostId);
    el && el.classList.add('disabled');
  },
  
  deletePost: function(id, slug, thread, post, file_only) {
    var params;
    
    params = [];
    params.push('board=' + slug);
    params.push('thread=' + thread);
    params.push('post=' + post);
    params.push('csrf=' + $.getCookie('csrf'));
    
    if (file_only) {
      params.push('file_only=1');
    }
    
    $.xhr('POST', '/manage/posts/delete',
      {
        onload: Hive.onPostDeleted,
        hivePostId: id
      },
      params.join('&')
    );
  },
  
  onDeletePostClick: function(t) {
    var el, path, slug, thread, post, file_only;
    
    el = $.postIdFromNode(t);
    
    if (!el) {
      return;
    }
    
    file_only = t.hasAttribute('data-delfile');
    
    path = el.id.split('-');
    
    if (path.length < 3) {
      post = path.pop();
      path = location.pathname.split('/');
      slug = path[1];
      thread = path[3];
    }
    else {
      post = path.pop();
      thread = path.pop();
      slug = path.pop();
    }
    
    Hive.deletePost(el.id, slug, thread, post, file_only);
  },
  
  onLockThreadClick: function(btn) {
    var board, thread, params, value;
    
    board = document.body.getAttribute('data-board');
    thread = document.body.getAttribute('data-thread');
    value = +!document.body.hasAttribute('data-locked');
    
    params = [
      'board=' + board,
      'thread=' + thread,
      'flag=locked',
      'value=' + value,
      'csrf=' + $.getCookie('csrf')
    ];
    
    $.xhr('POST', '/manage/threads/flags',
      {
        onload: Hive.onLockThreadLoaded
      },
      params.join('&')
    );
  },
  
  onLockThreadLoaded: function() {
    if (document.body.hasAttribute('data-locked')) {
      document.body.removeAttribute('data-locked');
    }
    else {
      document.body.setAttribute('data-locked', '1');
    }
  },
  
  onPinThreadClick: function(btn) {
    var board, thread, params, value, current_value;
    
    board = document.body.getAttribute('data-board');
    thread = document.body.getAttribute('data-thread');
    current_value = +document.body.getAttribute('data-pinned') || 1;
    
    value = prompt('Order (0 to unpin)', current_value);
    
    if (value === null) {
      return;
    }
    
    params = [
      'board=' + board,
      'thread=' + thread,
      'flag=pinned',
      'value=' + value,
      'csrf=' + $.getCookie('csrf')
    ];
    
    $.xhr('POST', '/manage/threads/flags',
      {
        onload: Hive.onPinThreadLoaded,
        hiveValue: value
      },
      params.join('&')
    );
  },
  
  onPinThreadLoaded: function() {
    if (this.hiveValue === 0) {
      document.body.removeAttribute('data-pinned');
    }
    else {
      document.body.setAttribute('data-pinned', this.hiveValue);
    }
  },
  
  addManagerControls: function() {
    var i, cnt, el, nodes, ctrl, path, post_id;
    
    // fixme
    path = location.pathname.split('/');
    path = '/manage/bans/create/' + path[1] + '/' + path[3] + '/';
    
    nodes = $.cls('post-head');
    
    for (i = 0; el = nodes[i]; ++i) {
      post_id = el.parentNode.id.split('-').pop();
      
      cnt = $.el('span');
      cnt.className = 'manage-ctrl';
      
      ctrl = $.el('a');
      ctrl.setAttribute('data-cmd', 'delete-post');
      ctrl.setAttribute('data-tip', 'Delete');
      ctrl.textContent = 'D';
      cnt.appendChild(ctrl);
      
      ctrl = $.el('a');
      ctrl.setAttribute('data-cmd', 'delete-post');
      ctrl.setAttribute('data-delfile', '1');
      ctrl.setAttribute('data-tip', 'Delete file');
      ctrl.textContent = 'Df';
      cnt.appendChild(ctrl);
      
      ctrl = $.el('a');
      ctrl.setAttribute('target', '_blank');
      ctrl.setAttribute('data-tip', 'Ban');
      ctrl.href = path + post_id;
      ctrl.textContent = 'B';
      cnt.appendChild(ctrl);
      
      if (post_id === '1') {
        ctrl = $.el('a');
        ctrl.setAttribute('data-cmd', 'pin-thread');
        ctrl.setAttribute('data-tip', 'Pin thread');
        ctrl.textContent = 'P';
        cnt.appendChild(ctrl);
        
        ctrl = $.el('a');
        ctrl.setAttribute('data-cmd', 'lock-thread');
        ctrl.setAttribute('data-tip', 'Lock thread');
        ctrl.textContent = 'L';
        cnt.appendChild(ctrl);
     }
      
      el.appendChild(cnt);
    }
  }
};

Hive.init();
