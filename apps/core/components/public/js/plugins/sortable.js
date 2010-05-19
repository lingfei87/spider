Spider.Sortable = Spider.Plugin.extend({
	
	
    makeSortable: function(options){
		var options = $.extend({
			listSelector: 'ul',
			items: '>li',			
			update: this.handleSort.bind(this),
			receive: this.handleReceive.bind(this)
		}, options);
		this.listEl = options.listEl;
		if (!this.listEl) this.listEl = $(options.listSelector, this.el);
        if (this.el.hasClass('tree')){
            options = $.extend(options, {
    			//revert: true,
    			sortIndication: {
    				down: function(item) {
						item.before($('<li id="list-sort-indicator" />'));
    				},
    				up: function(item) {
						item.after($('<li id="list-sort-indicator" />'));
    				},
    				remove: function(item) {
						$('#list-sort-indicator').remove();
    				}
    			},
    			start: function(e, ui) {
                    console.log("Tree start:");
                    console.log(e);
                    console.log(ui);
//					ui.instance.element.treeview({update: ui.item});
				},
				update: this.handleTreeUpdate.bind(this)
            });
            this.listEl.sortableTree(options);
            // handles drops on non-subtrees nodes
//            debugger;
            $('.desc', this.el).droppable({
                accept: "li",
                hoverClass: "drop",
                tolerance: "pointer",
//                greedy: true,
                drop: this.handleTreeDrop.bind(this)
                // over: function(e,ui) {
                //     ui.helper.css("outline", "1px dotted green");
                // },
                // out: function(e,ui) {
                //     ui.helper.css("outline", "1px dotted red");
                // }
            });
        }
        else{
            this.listEl.sortable(options);
        }
    },

	
    
    handleSort: function(e, ui){
		if (ui.sender) return; // handled by handleReceive
        var item = ui.item;
        var pos = this.findLiPosition(item);
		if (pos == -1) return;
		if (this.listEl.data('sortable').fromOutside){ // hack to work around strange jquery ui behaviour...
			return this.acceptFromSender(null, ui.item, pos);
		}
		this.remote('sort', this.getSortItemId(item), pos);
    },


	handleReceive: function(e, ui){
		if (ui.sender == ui.item){
			// the item is received from a draggable, not from a list. For some reason the receiver is not
			// yet ready to find the position; will call acceptFromSender from handleSort.
			return;
		}
		var pos = this.findLiPosition(ui.item);
		return this.acceptFromSender(ui.sender, ui.item, pos);
	},
    
    handleTreeUpdate: function(e, ui){
        var parentId = ui.item.parents('li.tree').eq(0).dataObjectKey();
        var prevId = ui.item.prev('li.tree').dataObjectKey();
        this.remote('tree_sort', this.getItemId(ui.item), parentId, prevId);
    },
    
    handleTreeDrop: function(e, ui){
        if (e.target.parentNode == ui.draggable[0]) return false; //dropped over itself
        console.log('dropped inside');
        var dropLi = $(e.target.parentNode);
        var subUl = $("> "+this.listTagName, dropLi);
        if (subUl.length == 0){
            subUl = $("<"+this.listTagName+" />").appendTo(dropLi);
            this.el.treeview({add: e.target.parentNode});
        }
        subUl.append(ui.draggable);
		var parentId = $(e.target).parents('li.tree').eq(0).dataObjectKey();
		var prevId = null;
		this.remote('tree_sort', ui.draggable.dataObjectKey(), parentId, prevId);
		return false;
    },

	acceptFromSender: function(sender, item, pos){
		console.error("Accept from sender must be implemented by the widget instance");
	},
	
	findLiPosition: function(item){
		var cnt = 1;
		var li = $('> li', this.listEl);
        li.each(function(){
            if (this == item.get(0)) return false;
            cnt++;
        });
		if (cnt > li.length) return -1; // the row was dropped outside
		return cnt;
	},
	
	getSortItemId: function(li){
		var k = $('> .sort-key', li);
		if (k.length > 0) return k.text();
		return li.dataObjectKey();
	}
	
});