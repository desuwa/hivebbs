'use strict';

var Reports = {
  init: function() {
    ClickHandler.commands['delete-post'] = Reports.onDeletePostClick;
    ClickHandler.commands['dismiss-report'] = Reports.onDismissReportClick;
  },
  
  onDeletePostClick: function(t) {
    var el, path, board, thread, pid, file_only;
    
    el = $.postFromNode(t);
    
    if (!el) {
      return;
    }
    
    path = el.id.split('-');
    
    board = path[0];
    thread = path[1];
    pid = path[2];
    file_only = t.hasAttribute('data-delfile');
    
    Hive.deletePost(el.id, board, thread, pid, file_only);
  },
  
  onDismissReportClick: function(t) {
    var post_id, params, el;
    
    el = $.postFromNode(t);
    
    if (!el) {
      return;
    }
    
    post_id = el.getAttribute('data-post-id');
    
    params = 'post_id=' + post_id + '&csrf=' + $.getCookie('csrf');
    
    $.xhr('POST', '/manage/reports/delete',
      {
        onload: Reports.onPostDeleted,
        hivePostId: el.id
      },
      params
    );
  },
  
  onPostDeleted: function() {
    var el = $.id(this.hivePostId);
    el && el.classList.add('disabled');
  },
};

Reports.init();
