function onPostDeleted() {
  // TODO: confirmation page should return a JSON with the post id.
  var el = $.id('post-' + this.hivePostId);
  el && el.classList.add('disabled');
}

function deletePost(slug, thread, post) {
  var form
  
  form = new FormData();
  form.append('board', slug);
  form.append('thread', thread);
  form.append('post', post);
  form.append('csrf', $.getCookie('csrf'));
  
  $.xhr('POST', '/manage/posts/delete',
    {
      onload: onPostDeleted,
      hivePostId: post
    }, form
  );
}

function onManagerClick(e) {
  var t, path, post;
  
  if (e.target.getAttribute('data-cmd') === 'delete-post' && confirm('Sure?')) {
    e.preventDefault();
    path = location.pathname.split('/');
    post = e.target.parentNode.parentNode.parentNode.id.split('-').pop();
    deletePost(path[1], path[3], post);
  }
}

function initManagerControls() {
  var i, cnt, el, nodes, ctrl, path, post;
  
  $.off(document, 'DOMContentLoaded', initManagerControls);
  $.on(document, 'click', onManagerClick);
  
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
    
    post = el.parentNode.id.split('-').pop();
    ctrl = document.createElement('a');
    ctrl.setAttribute('target', '_blank');
    ctrl.href = path + post;
    ctrl.textContent = 'ban';
    cnt.appendChild(ctrl);
    
    el.appendChild(cnt);
  }
}

$.on(document, 'DOMContentLoaded', initManagerControls);
