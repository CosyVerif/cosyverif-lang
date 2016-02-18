
    Array.prototype.top = function(){
        var ret = this.length > 0 ? this[this.length-1] : null;
        return ret;
    }
    // Size definitions for the shapes
    var rect_size = 30,
        rect_highlighted = 40,
        radius = rect_size / 2;
        radius_highlighted = (rect_size / 1.2);
    
    // Definitions of each of the shapes represented in the force layout.
    // Each new shape must be defined here

    var shapes = {
        rect : {
            d: "M " + -rect_size + " " + (-rect_size / 4) + " h " + 2 * rect_size + " v " + (rect_size / 2) + " h "+ (-2 * rect_size) + " z",
            
            anchors:{"N" : {x:0, y:(-rect_size/4)},
                     "E" : {x:rect_size, y:0},
                     "S" : {x:0, y:(rect_size/4)},
                     "W" : {x:-rect_size, y:0},
                     "NE" : {x:rect_size, y:-rect_size/4},
                     "SE" : {x:rect_size, y:rect_size/4},
                     "SW" : {x:-rect_size, y:rect_size/4},
                     "NW" : {x:-rect_size, y:-rect_size/4}}
        },
        
        rect_highlighted : {
            d: "M " + -rect_highlighted + " " + (-rect_highlighted / 4) + " h " + 2 * rect_highlighted + " v " + (rect_highlighted / 2) + " h "+ (-2 * rect_highlighted) + " z",
            anchors : {"N" : {x:0, y:(-rect_highlighted/4)},
                     "E" : {x:rect_highlighted, y:0},
                     "S" : {x:0, y:(rect_highlighted/4)},
                     "W" : {x:-rect_highlighted, y:0},
                     "NE" : {x:rect_highlighted, y:-rect_highlighted/4},
                     "SE" : {x:rect_highlighted, y:rect_highlighted/4},
                     "SW" : {x:-rect_highlighted, y:rect_highlighted/4},
                     "NW" : {x:-rect_highlighted, y:-rect_highlighted/4}}
        },
        
        vertical_rect : {
            d: "M " + (-rect_size / 4) + " " + -rect_size + " h " + (rect_size / 2) + " v " + 2 * rect_size + " h "      + (-rect_size / 2) + " z",
            anchors : {"N" : {x:0, y:(-rect_size/4)},
                     "E" : {x:rect_size, y:0},
                     "S" : {x:0, y:(rect_size/4)},
                     "W" : {x:-rect_size, y:0},
                     "NE" : {x:rect_size, y:-rect_size/4},
                     "SE" : {x:rect_size, y:rect_size/4},
                     "SW" : {x:-rect_size, y:rect_size/4},
                     "NW" : {x:-rect_size, y:-rect_size/4}}
        },
        
        circle : {
            d: "M 0 0 m" + (-radius) +", 0 a " + radius + "," + radius + " 0 1,0 " + (radius * 2) +",0 " 
                        + "a " + radius + "," + radius + " 0 1,0 " + (-radius * 2) + ",0",
            anchors : {"N" :    {x:Math.cos(Math.PI/2)*radius,      y:-Math.sin(Math.PI/2)*radius},
                     "E" :       {x:Math.cos(0)*radius,              y:Math.sin(0)*radius},
                     "S" :      {x:Math.cos(3/2*Math.PI)*radius,    y:-Math.sin(3/2*Math.PI)*radius},
                     "W" :       {x:Math.cos(Math.PI)*radius,        y:Math.sin(Math.PI)*radius},
                     "NE" :  {x:Math.cos(Math.PI/4)*radius,      y:-Math.sin(Math.PI/4)*radius},
                     "SE" :  {x:Math.cos(7/4*Math.PI)*radius,    y:-Math.sin(7/4*Math.PI)*radius},
                     "SW" :  {x:Math.cos(5/4*Math.PI)*radius,    y:-Math.sin(5/4*Math.PI)*radius},
                     "NW" :  {x:Math.cos(3/4*Math.PI)*radius,    y:-Math.sin(3/4*Math.PI)*radius}}
        },
        
        circle_highlighted : {
            d: "M 0 0 m" + (-radius_highlighted) +", 0 a " + radius_highlighted + "," + radius_highlighted + " 0 1,0 " + (radius_highlighted * 2) +",0 " + "a " + radius_highlighted + "," + radius_highlighted + " 0 1,0 " + (-radius_highlighted * 2) + ",0",
            anchors : {"N" : {x:Math.cos(Math.PI/2)*radius_highlighted,  y:-Math.sin(Math.PI/2)*radius_highlighted},
                     "E" : {x:Math.cos(0)*radius_highlighted,         y:Math.sin(0)*radius_highlighted},
                     "S" : {x:Math.cos(3/2*Math.PI)*radius_highlighted,y:-Math.sin(3/2*Math.PI)*radius_highlighted},
                     "W" : {x:Math.cos(Math.PI)*radius_highlighted,   y:Math.sin(Math.PI)*radius_highlighted},
                     "NE" :{x:Math.cos(Math.PI/4)*radius_highlighted,     y:-Math.sin(Math.PI/4)*radius_highlighted},
                     "SE" :{x:Math.cos(7/4*Math.PI)*radius_highlighted,   y:-Math.sin(7/4*Math.PI)*radius_highlighted},
                     "SW" :{x:Math.cos(5/4*Math.PI)*radius_highlighted,   y:-Math.sin(5/4*Math.PI)*radius_highlighted},
                     "NW" :{x:Math.cos(3/4*Math.PI)*radius_highlighted,   y:-Math.sin(3/4*Math.PI)*radius_highlighted}}
            
        },
    };

    // OBECTJS AND D3 INITIALIZATION
    
    // Cosy object for server comunitacion
    var Cosy = null;
    
    // Position definitions and points of reference for the markers
    var width = 700,
        height = 450,
        markerSize = 8,
        origin = {x: width/2, y: height/2};
        
    var svg = d3.select("#model_container").append("svg:svg")
            .attr("class", "svg_container")
            .attr("width", width)
            .attr("height", height)
            .style("pointer-events", "all");
    
    function change_size_svg(h, w) {
        d3.select('.svg_container').attr('width', w).attr('height', h);
    }

    var zm = d3.behavior.zoom().on("zoom", rescale);
    
    var outer = svg.append("g")
                .attr("class", "outer")
                .call(zm)
                .on("dblclick.zoom", null);

    var container = outer.append("g")
                .attr("class", "container")
                .on("contextmenu", function(data, index) { d3.event.preventDefault(); })
                .on("mousedown", mouseDown)
                .on("mousemove", mouseMove)
                .on("mouseup", mouseUp);
    
    // Background color
    container.append('svg:rect')
        .attr('class', 'click-capture')
        .attr('width', width)
        .attr('height', height)
        .attr('visibility', 'hidden');
                
    var drag_line = container.append("line")
        .attr("class", "drag_line")
        .attr("x1", 0)
        .attr("y1", 0)
        .attr("x2", 0)
        .attr("y2", 0);
      
    d3.select("#model_container").append("div")
        .attr("id", "forms_group")
        .attr("class", "span5");
    
    var force = d3.layout.force()
        .size([width, height])
        .nodes([])
        .links([])
        .on("tick", tick);
    
    // Arrowheads definitions
    container.append("svg:defs").selectAll("marker")
        .data(["arc"])      // Different link/path types can be defined here
        .enter().append("svg:marker")    // This section adds in the arrows
        .attr("id", String)
        .attr("viewBox", "0 -5 10 10")
        .attr("refX", markerSize)
        .attr("markerWidth", markerSize)
        .attr("markerHeight", markerSize)
        .attr("orient", "auto")
        .append("svg:path")
        .attr("d", "M0,-5L10,0L0,5");
    
    var nodes_index = {},
        links_index = {},
        forms_index = {},
        node_stack = [];
        
    // This definition of drag allows to drag only with a right click
    var dragInitiated;
    var nodeDrag = d3.behavior.drag()
        .on("dragstart", function(d, i) {
            console.log('drag Start');
            if(d3.event.sourceEvent.which == 1){
                d3.event.sourceEvent.stopPropagation();
                dragInitiated = true;
                force.stop();
                var point = [d.x, d.y];
                pressTimerLeft = window.setTimeout(function(){ left_longClick(point); },800);
            }
        })
        .on("drag", function(d, i) {
            if (dragInitiated){
                d.px += d3.event.dx;
                d.py += d3.event.dy;
                d.x += d3.event.dx;
                d.y += d3.event.dy;
                tick();
            }
        })
        .on("dragend", function(d, i){
            if (d3.event.sourceEvent.which == 1){
                force.resume();
                tick();
                dragInitiated = false;
            }
        });

    // Definitions of all the elements from the force layot.
    // the circle represents a token for each node. 
    var path = container.append("svg:g").attr('class', 'paths').selectAll("path"),
        node = container.append("svg:g").attr('class', 'nodes').selectAll("node"),
        circle = container.append("svg:g").attr('class', 'tokens').selectAll("g"),
        text = container.append("svg:g").attr('class', 'names').selectAll("g");
    
    // Update node notification from server
    function update_node (node) {
        console.log('Update a Node');
        updateModelNode(node);
    }
    
    function update_arc (arc) {
        console.log('Update an Arc')
        updateModelNode(arc);
    }
    
    function updateModelNode(node) {
        //~ var types = Cosy.types()
        //~ var lua_place = types['place_type'];
        //~ Cosy.is(node, place_type)
        if(Cosy.is_arc(node)){
            var source = Cosy.source(node),
                target = Cosy.target(node),
                anchor = '',
                lock_pos = false;
            source = force.nodes()[nodes_index[Cosy.id(source)]];
            target = force.nodes()[nodes_index[Cosy.id(target)]];
            
            if(!source || !target) return;
            
            if(undefined == links_index[Cosy.id(node)]){
                force.links().push({id : Cosy.id(node), 
                                    anchor: anchor,
                                    source: source,
                                    target: target,
                                    type: "arc",
                                    lock_pos : lock_pos});
                                    
                links_index[Cosy.id(node)] = force.links().length - 1;
            } else {
                var i = links_index[Cosy.id(node)];
                force.links()[i].source = source;            
                force.links()[i].target = target;
                force.links()[i].anchor = anchor;
                force.links()[i].lock_pos = lock_pos;
            }
        } else if(Cosy.is_place(node) || Cosy.is_transition(node)){
            
            
            if(Cosy.get_name(node) == undefined) return;
            
            marking = Cosy.get_token(node) ? Cosy.get_token(node) : '';
            highlighted = Cosy.is_highlighted(node) ? Cosy.is_highlighted(node) : '';
            selected = Cosy.is_selected(node) ? Cosy.is_selected(node) : '';
            name = Cosy.get_name(node);
            isTransition = Cosy.is_transition(node);
            if(highlighted)
                shape = isTransition ? shapes.rect_highlighted : shapes.circle_highlighted;
            else
                shape = isTransition ? shapes.rect : shapes.circle;
            
            var s = Cosy.get_position(node) ? Cosy.get_position(node) : '[0,0]';
            var is_polar = s.indexOf(",") == -1,
                x_pos, y_pos, p;
            
            
            if(is_polar)
                p = s.indexOf(":")
            else
                p = s.indexOf(",")
            
            
            var offset_x = is_polar ? Math.cos(s.substring(0, p)*(180/Math.PI)) * s.substring(p+1) : s.substring(0, p)
            var offset_y = is_polar ? Math.sin(s.substring(0, p)*(180/Math.PI)) * s.substring(p+1) : s.substring(p+1)
            
            var x_pos = parseFloat(origin.x) + parseFloat(offset_x);
            var y_pos = parseFloat(origin.y) - parseFloat(offset_y);
            elem = {id : Cosy.id(node),
                    name : name,
                    type : isTransition ? 'transition' : 'place',
                    shape : shape,
                    marking : marking ? true : false,
                    px : x_pos,
                    py : y_pos,
                    highlighted : highlighted,
                    selected : selected,
                    lua_node :node };
            if(undefined == nodes_index[Cosy.id(node)]){
                elem.fixed = true;
                force.nodes().push(elem);
                console.log('Saving new node in javascript: ' + Cosy.id(node));
                nodes_index[Cosy.id(node)] = force.nodes().length - 1;
            } else {
                i = nodes_index[Cosy.id(node)];
                force.nodes()[i].id = elem.id;
                force.nodes()[i].name = elem.name;
                force.nodes()[i].type = elem.type;
                force.nodes()[i].shape = elem.shape;
                force.nodes()[i].marking = elem.marking;
                force.nodes()[i].px = elem.px;
                force.nodes()[i].py = elem.py;
                force.nodes()[i].highlighted = elem.highlighted;
                force.nodes()[i].selected = elem.selected;
                force.nodes()[i].lua_node = elem.lua_node;
            }
        } 
        //~ else if("form" == node.get("type")){
            //~ // TODO: This is not tested.
            //~ var unsorted_forms = elements(node);
            //~ var form_elems = [];
            //~ for(j = 1; j <= count(unsorted_forms); j++){
                //~ form_elems.push(unsorted_forms.get(j));
            //~ }
            //~ form_elems.sort(function sortForms(x, y) {
                //~ if("text" == x.get("type"))
                    //~ return -1;
                //~ if(y_value = "text" == y.get("type"))
                    //~ return 1;
                //~ return 0;
            //~ });
            //~ 
            //~ var selection = d3.select("#forms_group");
            //~ var data = selection.data();
            //~ data[id(node)] = node;
            //~ selection = selection.data(data, function(d) { return id(node)});
            //~ 
            //~ selection.enter().append("div")
                    //~ .attr("id", id(node))
                    //~ .attr("class", "lua_form");
            //~ 
            //~ for(j = 0; j < count(form_elems); j++){
                //~ form = form_elems[j];
                //~ sub_id = id(form);
                //~ if("text" == form.get("type")){
                    //~ selection.append("h4")
                        //~ .attr("id", sub_id+"_h4")
                        //~ .text(form.get("name"));
                    //~ selection.append("input").data([form])
                        //~ .attr("id", sub_id+"_text")
                        //~ .attr("type", "text")
                        //~ .attr("size", 9)
                        //~ .on("change", formTextChange)
                        //~ .attr("value", form.get("value"));
                //~ } else if("button" == form.get("type")) {
                    //~ btn = selection.append("button").data([form]);
                    //~ btn.attr("type", "button")
                        //~ .attr("id", sub_id)
                        //~ .attr("class", "btn btn-success")
                        //~ .attr("data-toggle", "button")
                        //~ .on("click", formBtnClick)
                        //~ .text(form.get("name"));
                    //~ if(!form.get("is_active")) {
                        //~ btn.attr("disabled", "true")
                    //~ }
                //~ }
            //~ }
        //~ }
        updateForceLayout();
    }

    function remove(node) {
        console.log('Remove called from server to node: ' + node.id);
        var index_object, list;
        
        if(node.type == 'arc'){
            index_object = links_index;
            list = force.links();
        } else if(node.type == 'place' || node.type == 'transition'){
            index_object = nodes_index;
            list = force.nodes();
        }
        
        if(list && index_object) {
            console.log("node to remove", node.id)
            //~ for(var x in index_object){
                //~ console.log([x, index_object[x]])
            //~ }
            list.splice(index_object[node.id], 1)
            
            var index = index_object[node.id];
            
            delete index_object[node.id];
            
            /*We need to update all the indexes*/
            for(var e in index_object){
                index_object[e] = index < index_object[e] ? index_object[e] - 1 : index_object[e];
            }
            
            //~ for(var x in index_object){
                //~ console.log([x, index_object[x]])
            //~ }
            //~ if(node.type == 'place' || node.type == 'transition'){
                //~ var temp = force.links();
                //~ for(var i = 0; i < temp.length; i++) {
                    //~ var l = force.links()[i];
                    //~ if(l.source.id == node.id || l.target.id == node.id){
                        //~ 
                        //~ temp.splice(links_index[l.id], 1)
                        //~ delete links_index[l.id];
                    //~ }
                //~ }
            //~ }
            updateForceLayout();
        }
    }
    
    // User add new node
    function addNodeToModel(node) {
        if(Cosy) {
            Cosy.create(Cosy.resource(), source, link_type, target_type, data);
            Cosy.instantiate(Cosy.resource(), target_type, data);
        }
    }
    
    // User remove node
    function removeNodeFromModel(node) {
        if(Cosy) {
            console.log("Cosy.remove " + node.lua_node)
            Cosy.remove(node.lua_node);
        }
    }
    
    function editAttribute(node) {
        console.log('#' + node.id);
        $('#' + node.id).replaceWith(function(){
            var input = $('<input />', { value: $(this).text(), 'class': 'node_name', 'id': node.id});
            input.on('keyup', function(e){
                if(e.which == 13) {
                    // TODO: Cosy Node modification. 
                }
            });
            return input;
        });
        $('#' + node.id).focus();
    }
    
    function websocket (url) {
        console.log ("new websocket: " + url);
        return new WebSocket (url, "cosy");
    }
    
    function add_patch (str) {
    }
    
    function setCosyObject (obj){
        Cosy = obj;
    }
    
    // GUI update
    function updateForceLayout() {
        assert(force.nodes().length != nodes_index.length, "Error: Force nodes amount diferrent from indexed nodes");
        assert(force.links().length != links_index.length, "Error: Force links amount diferrent from indexed links");
        
        path = path.data(force.links(), function(d) { return d.id });
        path.enter().insert("svg:path", ".node");
        path.attr("class", function (d) {return "link " + d.type;})
            .attr("marker-end", function (d) {return "url(#" + d.type + ")";});
        path.exit().remove();
        
        //~ console.log('Nodes: ' + force.nodes());
        node = node.data(force.nodes(), function (d) { return d.id });
        node.enter().append("path");
        node.attr("class", function(d){ return d.selected ? "node selected" : "node"})
            .attr("d", function(d){ return d.shape.d;})
            .attr("fill", function(d){ return d.highlighted ? "gold" : "#ccc"})
            .style("stroke-width", '1.5px')
            .on('mouseenter', node_mouseEnter)
            .on('mouseout', node_mouseExit)
            .call(nodeDrag);
        node.exit().remove();
        
        circle = circle.data(force.nodes(), function (d) {return d.id;});
        circle.enter().append("circle")
                .attr("class", "token")
                .attr("r", radius/6)
                .attr("fill", "black")
                .on('mouseenter', node_mouseEnter)
                .on('mouseleave', node_mouseExit)
                //~ .call(nodeDrag);
        circle.attr("visibility", function(d) {return d.marking ? "visible" : "hidden" })
        circle.exit().remove();
        
        //~ text = text.data(force.nodes(), function (d) {return d.id;});
        //~ text.enter().append("text")
            //~ .attr("class", "node_name")
            //~ .attr("x", function(d){ return d.type == 'transition' ? 45 : 30})
            //~ .attr("y", ".45em")
            //~ .attr("size", 10)
            //~ .on('click', editAttribute);
        //~ text.text(function(d) { return d.name; });
        
        text = text.data(force.nodes(), function (d) {return d.id;});
        text.enter().append("foreignObject")
            .attr("class", "labels")
            .attr("x", function(d){ return d.type == 'transition' ? 30 : 15})
            .attr("height", 20)
            .attr("width", 120)
            .on('dblclick', editAttribute)
            .append('xhtml:text')
                .attr('class', 'node_name')
                .attr('id', function(d){ return d.id; })
                .attr('type', 'text')
                .html(function(d) { return d.name; });
            
        
        text.exit().remove();
        force.start();
        console.log("#Nodes: " + force.nodes().length+" #Links: " + force.links().length);
        return true;
    }
    
    // Zoom and rescale event handling
    function rescale() {
        container.attr("transform"," translate("+d3.event.translate+") scale(" + d3.event.scale + ")");
        d3.selectAll('.node').each( function(d, i){
            var stroke = d3.select(this).style('stroke-width');
            d3.select(this).style('stroke-width', 1.5 / zm.scale() + 'px')
        });
    }
    
    // Mouse event vars
    var newLinkValues = {arc_initiated: false, source_node:null};
    var cancelUpEvent = false;
    var pressTimerRight = null;
    var pressTimerLeft = null;
    
    // User selected type. FIXME: On implementation of "lua types", change this var
    var new_elem_type = "place";
    
    function resetMouseVars() {
        newLinkValues.arc_initiated= false;
        newLinkValues.source_node= null;
        clearTimeout(pressTimerRight);
        clearTimeout(pressTimerLeft);
    }
    
    // Mouse event handling
    
    function mouseDown() {
        console.log("Mouse down")
        var point = d3.mouse(this);
        switch(d3.event.button){
            case 0:     /*left click*/
                d3.event.stopPropagation();
                break;
            case 1:     /*middle click*/
                 break;
            case 2:     /*right click*/
                d3.event.stopPropagation();
                d3.event.preventDefault();
                if(node_stack.length > 0){
                    newLinkValues.arc_initiated = true;
                    newLinkValues.source_node = node_stack.top();
                    drag_line
                      .attr("class", "drag_line")
                      .attr("x1", newLinkValues.source_node.x)
                      .attr("y1", newLinkValues.source_node.y)
                      .attr("x2", newLinkValues.source_node.x)
                      .attr("y2", newLinkValues.source_node.y);
                } else {
                    pressTimerRight = window.setTimeout(function(){ right_longClick(point); },800);
                    newLinkValues.arc_initiated = false;
                    newLinkValues.source_node = null;
                }
        }
    }
    
    function mouseMove(){
        if (newLinkValues.arc_initiated){
            drag_line
                .attr("x1", newLinkValues.source_node.x)
                .attr("y1", newLinkValues.source_node.y)
                .attr("x2", d3.mouse(this)[0])
                .attr("y2", d3.mouse(this)[1]);
        } else {
            resetMouseVars();
        }
    }
    
    function mouseUp() {
        console.log("Mouse up");
        if(cancelUpEvent) return;
        
        switch(d3.event.button){
            case 0:     /*left click*/
                break;
            case 1:     /*middle click*/
                break;
            case 2:     /*right click*/
                if(newLinkValues.arc_initiated){
                    var source = newLinkValues.source_node;
                    drag_line.attr("class", "drag_line_hidden")
                    var point = d3.mouse(this);
                    var node;
                    if(node_stack.length > 0) {
                        node = node_stack.top();
                        if(node == source) break;
                    }
                    else {
                        node = {id : "dummy_node_"+force.nodes().length,
                            name : "dummy_node_"+force.nodes().length,
                            type : source.type == "transition" ? "place" : "transition", 
                            shape : source.type == "transition" ? shapes.circle : shapes.rect,
                            x : point[0],
                            y : point[1],
                            position : point[0] + ','+point[1],
                            highlighted : false,
                            selected : false,
                            fixed : true};
                        force.nodes().push(node);
                    }
                    var temp_i = force.nodes().length - 1;
                    nodes_index["dummy_node_"+temp_i] = temp_i;

                    force.links().push({id : "dummy_link_"+force.links().length, 
                                anchor:"",
                                source: source,
                                target: node,
                                type: "arc",
                                lock_pos : false});
                    temp_i = force.links().length - 1;
                    links_index["dummy_link_"+temp_i] = temp_i;
                } else {
                    var point = d3.mouse(this),
                    node = {id : "dummy_node_"+force.nodes().length,
                        name : "dummy_node_"+force.nodes().length,
                        type : new_elem_type == "place" ? "place" : "transition", 
                        shape : new_elem_type == "place" ? shapes.circle : shapes.rect,
                        marking : true,
                        x : point[0],
                        y : point[1],
                        highlighted : false,
                        selected : false,
                        lua_node : null,
                        fixed : true};
                    force.nodes().push(node);
                    
                    var temp_i = force.nodes().length - 1;
                    nodes_index["dummy_node_" + temp_i] = temp_i;
                }
                arc_initiated = false;
                node_stack.pop();
                break;
        }
        updateForceLayout();
        resetMouseVars();
    }
    
    function left_longClick(point){
        console.log("Left long click", point);
        var node_data = node_stack.top();
        if(!d3.select(".node_options").empty()) {
            removeOptionsMenu();
        }
        removePalette();
        var options_menu = container.append("g").attr("class", "node_options");
        var size = 100;
        
        var foreign = options_menu.append("foreignObject")
                .attr("x", point[0]-size/2)
                .attr("y", point[1]-size/2)
                .attr("height", size)
                .attr("width", size);
                
        var menu_container = foreign.append("xhtml:div")
                                .attr("class", "node-options-menu")
        
        
        var menu = menu_container.append("xhtml:div")
                        .attr("class", "node-options-container")
                        
        var buttons_data = [{icon: "fa fa-edit fa-lg", f:function(node){ console.log('TODO: Implement model view') }}, 
                            {icon: "fa fa-trash-o fa-lg", f: function(node){ removeNodeFromModel(node); }}];
        
        menu.selectAll("a")
            .data(buttons_data)
            .enter().append("a")    
                .attr("class", function(d){ return d.icon; })
                .attr("href", "")
                .attr("onclick", "return false") // To prevent reload when clicked.
                .on("click", function(d){ removeOptionsMenu(); d.f(node_data) ; return false;});
        
        var items = document.querySelectorAll('.node-options-container a');
        var offset = node.type == 'place' ? 35 : 45
        items[0].style.left = (50 - offset* Math.cos(-0.5 * Math.PI - 2*(1/5)*1*Math.PI)).toFixed(4) + "%";
        items[0].style.top = (50 + offset* Math.sin(-0.5 * Math.PI - 2*(1/5)*1*Math.PI)).toFixed(4) + "%";
        items[1].style.left = (50 - offset* Math.cos(-0.5 * Math.PI - 2*(1/5)*4*Math.PI)).toFixed(4) + "%";
        items[1].style.top = (50 + offset* Math.sin(-0.5 * Math.PI - 2*(1/5)*4*Math.PI)).toFixed(4) + "%";
        
        /*
         * The animation is coded in the css.
         * The transition is fired when the container adds
         * the class open
         */
        window.setTimeout(function(d) {d3.select('.node-options-container').classed('open', true) }, 50);
    }

    function right_longClick(point){
        console.log("Right Long click");
        if(!d3.select(".palette").empty()) {
            removePalette();
        }
        removeOptionsMenu();
        cancelUpEvent = true;
        var pallet_menu = container.append("g").attr("class", "palette");
        
        var size = 250;
        
        var foreign = pallet_menu.append("foreignObject")
                .attr("x", point[0]-size/2)
                .attr("y", point[1]-size/2)
                .attr("height", size)
                .attr("width", size);
        
        var menu_container = foreign.append("xhtml:div")
                                .attr("class", "circular-menu")
        
        
        var menu = menu_container.append("xhtml:div")
                        .attr("class", "circle_container")
                        .attr("height", size)
                        .attr("width", size);
        
        var buttons_data = [{ type: "trans", icon: "fa fa-arrows-h fa-2x"},
                            { type: "place", icon: "fa fa-circle-o fa-2x"},
                            { type: "trans", icon: "fa fa-arrows-h fa-2x"},
                            { type: "place", icon: "fa fa-circle-o fa-2x"}];
        
        
        menu.selectAll("a")
            .data(buttons_data)
            .enter().append("a")
                .attr("class", function(d){ return d.icon; })
                .attr("href", "")
                .attr("onclick", "return false") // To prevent reload when clicked.
                .on("click", function(d){ new_elem_type = d.type; removePalette(); return false;});
            
        var items = document.querySelectorAll('.circle_container a');
        for(var i = 0, l = items.length; i < l; i++) {
            items[i].style.left = (50 - 35* Math.cos(-0.5 * Math.PI - 2*(1/l)*i*Math.PI)).toFixed(4) + "%";

            items[i].style.top = (50 + 35* Math.sin(-0.5 * Math.PI - 2*(1/l)*i*Math.PI)).toFixed(4) + "%";
        }
        
        /*
         * The animation is coded in the css.
         * The transition is fired when the container adds
         * the class open
         */
        window.setTimeout(function(d) {d3.select('.circle_container').classed('open', true) }, 50);
    }
    
    function removePalette(){
        d3.select(".palette").remove();
        cancelUpEvent = false;
    }
    
    function removeOptionsMenu(){
        d3.select(".node_options").remove();
        cancelUpEvent = false;
    }
    
    function node_click(d){
        console.log('click')
        if (d3.event.defaultPrevented) return;
        d.lua_node.set("selected", !d.selected);
        d3.select(this).classed("selected", d.selected = !d.selected);
        console.log("Short click");
    }

    function node_mouseEnter(d){
        node_stack.push(d);
    }
    
    function node_mouseExit(d){
        node_stack.pop();
    }
    
    // Other events
    function formTextChange(d){
        d.set("value", this.value);
    }
    
    function formBtnClick(d){
        d.set("clicked", true);
    }
    
    function tick() {
        var duration = 50;
        path.transition().duration(duration).attr("d", function (d) {
            var offset;
            
            var anchor_list = d.target.type == "place" ? (d.target.highlighted ? shapes.circle_highlighted.anchors : shapes.circle.anchors) : (d.target.highlighted ? shapes.rect_highlighted.anchors : shapes.rect.anchors),
                min = Number.MAX_VALUE, dist;
                    
            if(!d.lock_pos || '' == d.anchor) {
                for(var key in anchor_list){
                    x_2 = Math.pow(d.source.x - (d.target.x + anchor_list[key].x), 2);
                    y_2 = Math.pow(d.source.y - (d.target.y + anchor_list[key].y), 2);
                    
                    dist = Math.sqrt(x_2 + y_2)
                    
                    if(dist < min){
                        min = dist;
                        d.anchor = key;
                        offset = anchor_list[key];
                    }
                }
            } else {
                offset = anchor_list[d.anchor];
            }
            
            return "M" + d.source.x + "," + d.source.y + "L" + (d.target.x+ offset.x) + "," + (d.target.y+offset.y);
        });
        
        node.transition().duration(duration).attr("transform", transform);
        circle.transition().duration(duration).attr("transform", transform);
        text.transition().duration(duration).attr("transform", transform);
        //~ text.attr('x', function(d){ return d.x; })
            //~ .attr('y', function(d){ return d.y; })
            
        function transform(d) {
            return "translate(" + d.x + "," + d.y + ")";
        }
    }
    
    // Extra functions
    function assert(condition, message) {
        if (!condition) {
            throw message || "Assertion failed";
        }
    }
