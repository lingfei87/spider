Spider.defineWidget('Spider.Components.Table', {
	
	autoInit: true,
	
	ready: function(){
		this.ajaxify($('.heading_row a, .paginator a', this.el));
	}

});