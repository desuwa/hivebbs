'use strict';

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
    
    if ($.body.classList.contains('has-backdrop') || PostMenu.node) {
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
    
    $.body.appendChild(cnt);
    
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
      
      $.body.removeChild(el);
    }
    
    QuotePreviews.hasPreviews = !!nodes[0];
  }
};

var PostMenu = {
  btn: null,
  node: null,
  items: [],
  
  init: function(items) {
    if (this.items.length) {
      ClickHandler.commands['p-m'] = this.onClick;
    }
    else {
      $.body.classList.add('no-post-menu');
    }
  },
  
  onClick: function(btn) {
    var i, item, items, len, cnt, el, baseEl;
    
    if (PostMenu.node) {
      PostMenu.close();
      
      if (PostMenu.btn === btn) {
        return;
      }
    }
    
    items = PostMenu.items;
    
    cnt = $.el('ul');
    cnt.id = 'post-menu';
    cnt.setAttribute('data-pid', $.postFromNode(btn).id.split('-').pop());
    
    for (i = 0, len = items.length; i < len; ++i) {
      item = items[i];
      
      if (typeof item === 'function') {
        item = item(btn);
        
        if (item === false) {
          continue;
        }
      }
      
      cnt.appendChild(item);
    }
    
    PostMenu.node = cnt;
    PostMenu.btn = btn;
    
    $.on(document, 'click', PostMenu.close);
    
    $.body.appendChild(cnt);
    
    PostMenu.adjustPos(btn, cnt);
  },
  
  adjustPos: function(btn, el) {
    var anchor, top, left, margin, style;
    
    margin = 4;
    
    anchor = btn.getBoundingClientRect();
    
    top = anchor.top + btn.offsetHeight + margin;
    left = anchor.left - el.offsetWidth / 2 + btn.offsetWidth / 2;
    
    if (left + el.offsetWidth > $.docEl.clientWidth) {
      left = $.docEl.clientWidth - el.offsetWidth - margin;
    }
    
    style = el.style;
    style.display = 'none';
    style.top = (top + window.pageYOffset) + 'px';
    style.left = (left + window.pageXOffset) + 'px';
    style.display = '';
  },
  
  close: function() {
    $.off(document, 'click', PostMenu.close);
    
    if (PostMenu.node) {
      PostMenu.node.parentNode.removeChild(PostMenu.node);
      PostMenu.node = null;
    }
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
      'report-post': Hive.onReportClick,
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
    
    page = $.body.getAttribute('data-page');
    
    if (page === 'read') {
      if ($.body.hasAttribute('data-reporting')) {
        Hive.initReportCtrl();
      }
      
      if ($.getCookie('csrf')) {
        Hive.initModCtrl();
      }
    }
    else if (page === 'report') {
      Hive.loadReCaptcha();
    }
    
    PostMenu.init();
    
    window.prettyPrint && window.prettyPrint();
  },
  
  initReportCtrl: function() {
    var el = $.el('li');
    
    el.innerHTML =
      '<span class="link-span" data-cmd="report-post">Report</span>';
      
    PostMenu.items.push(el);
  },
  
  onReportClick: function(t) {
    var board, thread, pid, src;
    
    board = $.body.getAttribute('data-board');
    thread = $.body.getAttribute('data-thread');
    pid = PostMenu.node.getAttribute('data-pid');
    
    src = '/report/' + board + '/' + thread
        + '/' + pid;
    
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
    
    $.body.classList.add('has-backdrop');
    
    $.body.appendChild(bg);
  },
  
  closeGallery: function() {
    var el;
    
    if (el = $.id('backdrop')) {
      $.body.removeChild(el);
      $.body.classList.remove('has-backdrop');
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
    var board, thread, pid, file_only;
    
    board = $.body.getAttribute('data-board');
    thread = $.body.getAttribute('data-thread');
    pid = PostMenu.node.getAttribute('data-pid');
    file_only = t.hasAttribute('data-delfile');
    
    Hive.deletePost(pid, board, thread, pid, file_only);
  },
  
  onLockThreadClick: function(btn) {
    var board, thread, params, value;
    
    board = $.body.getAttribute('data-board');
    thread = $.body.getAttribute('data-thread');
    value = +!$.body.hasAttribute('data-locked');
    
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
    if ($.body.hasAttribute('data-locked')) {
      $.body.removeAttribute('data-locked');
    }
    else {
      $.body.setAttribute('data-locked', '1');
    }
  },
  
  onPinThreadClick: function(btn) {
    var board, thread, params, value, current_value;
    
    board = $.body.getAttribute('data-board');
    thread = $.body.getAttribute('data-thread');
    current_value = +$.body.getAttribute('data-pinned') || 1;
    
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
      $.body.removeAttribute('data-pinned');
    }
    else {
      $.body.setAttribute('data-pinned', this.hiveValue);
    }
  },
  
  initModCtrl: function() {
    PostMenu.items.push(Hive.buildModCtrl);
  },
  
  buildModCtrl: function(el) {
    var cnt, ctrl, path, board, thread, post_id;
    
    board = $.body.getAttribute('data-board');
    thread = $.body.getAttribute('data-thread');
    
    path = '/manage/bans/create/' + board + '/' + thread + '/';
    
    el = $.postFromNode(el);
    
    post_id = el.id.split('-').pop();
    
    cnt = $.frag();
    
    ctrl = $.el('li');
    ctrl.innerHTML =
      '<span class="link-span" data-cmd="delete-post">Delete</span>';
    cnt.appendChild(ctrl);
    
    if ($.cls('post-file-thumb', el)[0]) {
      ctrl = $.el('li');
      ctrl.innerHTML =
        '<span class="link-span" data-delfile '
        + 'data-cmd="delete-post">Delete File</span>';
      cnt.appendChild(ctrl);
    }
    
    ctrl = $.el('li');
    ctrl.innerHTML =
      '<a href="' + path + post_id + '" target="_blank">Ban</a>';
    cnt.appendChild(ctrl);
    
    if (post_id === '1') {
      ctrl = $.el('li');
      ctrl.innerHTML =
        '<span class="link-span" data-cmd="pin-thread">Toggle Pin</span>';
      cnt.appendChild(ctrl);
      
      ctrl = $.el('li');
      ctrl.innerHTML =
        '<span class="link-span" data-cmd="lock-thread">Toggle Lock</span>';
      cnt.appendChild(ctrl);
   }
    
   return cnt;
  }
};

Hive.init();
