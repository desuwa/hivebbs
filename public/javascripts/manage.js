var Manage = {
  init: function() {
    Hive.clickCommands['delete-post'] = Manage.onDeletePostClick;
    Hive.clickCommands['dismiss-report'] = Manage.onDismissReportClick;
    
    if (/\/read\//.test(location.pathname)) {
      Manage.addManagerControls();
    }
  },
  
  onPostDeleted: function() {
    var el = $.id(this.hivePostId);
    el && el.classList.add('disabled');
  },
  
  getPostIdfromNode: function(el) {
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
  
  deletePost: function(id, slug, thread, post, file_only) {
    var form;
    
    form = new FormData();
    form.append('board', slug);
    form.append('thread', thread);
    form.append('post', post);
    form.append('csrf', $.getCookie('csrf'));
    
    if (file_only) {
      form.append('file_only', '1');
    }
    
    $.xhr('POST', '/manage/posts/delete',
      {
        onload: Manage.onPostDeleted,
        hivePostId: id
      }, form
    );
  },
  
  onDeletePostClick: function(t) {
    var el, path, slug, thread, post, file_only;
    
    el = Manage.getPostIdfromNode(t);
    
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
    
    Manage.deletePost(el.id, slug, thread, post, file_only);
  },
  
  onDismissReportClick: function(t) {
    var post_id, form, el;
    
    el = Manage.getPostIdfromNode(t);
    
    if (!el) {
      return;
    }
    
    post_id = el.getAttribute('data-post-id');
    
    form = new FormData();
    form.append('post_id', post_id);
    form.append('csrf', $.getCookie('csrf'));
    
    $.xhr('POST', '/manage/reports/delete',
      {
        onload: Manage.onPostDeleted, // fixme
        hivePostId: el.id
      }, form
    );
  },
  
  addManagerControls: function() {
    var i, cnt, el, nodes, ctrl, path, post;
    
    path = location.pathname.split('/');
    path = '/manage/bans/create/' + path[1] + '/' + path[3] + '/';
    
    nodes = $.cls('post-head');
    
    for (i = 0; el = nodes[i]; ++i) {
      cnt = $.el('span');
      cnt.className = 'manage-ctrl';
      
      ctrl = document.createElement('a');
      ctrl.setAttribute('data-cmd', 'delete-post');
      ctrl.textContent = 'del';
      cnt.appendChild(ctrl);
      
      ctrl = document.createElement('a');
      ctrl.setAttribute('data-cmd', 'delete-post');
      ctrl.setAttribute('data-delfile', '1');
      ctrl.textContent = 'delfile';
      cnt.appendChild(ctrl);
      
      post = el.parentNode.id.split('-').pop();
      ctrl = document.createElement('a');
      ctrl.setAttribute('target', '_blank');
      ctrl.href = path + post;
      ctrl.textContent = 'ban';
      cnt.appendChild(ctrl);
      
      el.appendChild(cnt);
    }
  }
};

$.on(document, 'DOMContentLoaded', Manage.init);
