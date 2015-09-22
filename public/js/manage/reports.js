var Reports = {
  init: function() {
    ClickHandler.commands['dismiss-report'] = Reports.onDismissReportClick;
  },
  
  onDismissReportClick: function(t) {
    var post_id, params, el;
    
    el = $.postIdFromNode(t);
    
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
