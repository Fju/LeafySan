function LineChart(elementId) {
	var svg = d3.select('#' + elementId),
		margin = { top: 20, right: 20, bottom: 30, left: 50 },
		width = 950 - margin.left - margin.right,
		height = 600 - margin.top - margin.bottom,
		g = svg.append('g').attr('transform', 'translate(' + margin.left + ',' + margin.top + ')');

	var element = document.getElementById(elementId),
		scaledWidth, scaleFactor;

	g.append('defs').append('svg:clipPath')
		.attr('id', 'clip')
		.append('svg:rect')
		.attr('id', 'clip-rect')
		.attr('x', 0)
		.attr('y', -10)
		.attr('width', width)
		.attr('height', height + 10);

	var colors = {
		temperature: '#f44336',
		moisture: '#178bca',
		brightness: '#dc9e04',
		carbondioxide: '#669900'
	};

	var xAxis, yAxis, data, domainTimeline, currentGraph = 'temperature';

	var scaleX = d3.scaleTime().range([0, width]);
	var scaleY = d3.scaleLinear().range([height, 0]);

	var line = d3.line().x(function(d) { return scaleX(d.date); }).y(function(d) { return scaleY(d[currentGraph]); }).curve(d3.curveBasis);

	var svg_xAxis = g.append('g').attr('transform', 'translate(0,' + height + ')').attr('id', 'line-chart-x-axis');
	var svg_yAxis = g.append('g').attr('id', 'line-chart-y-axis');
	var svg_axisLabel = svg_yAxis.append('text').attr('id', 'line-chart-axis-lbl').attr('fill', '#000').attr('transform', 'rotate(-90)').attr('y', 6).attr('dy', '0.71em').attr('text-anchor', 'end');
	var svg_graph = g.append('g').attr('clip-path', 'url(#clip)').append('path').attr('id', 'line-chart-graph').attr('fill', 'none').attr('stroke-linejoin', 'round').attr('stroke-width', 2);

	var onzoom = function(changeDomain) {
		if (!xAxis) return;
		var start = scaleX.domain()[0], end = scaleX.domain()[1];
		if (!changeDomain) {
			var t = d3.event.transform;
			var d0 = domainTimeline[0].getTime(), d1 = domainTimeline[1].getTime();
			start = d0 - (t.x / (width * scaleFactor * t.k)) * (d1 - d0);
			end = start + (d1 - d0) / d3.event.transform.k;

			console.log(start, end);
			scaleX.domain([new Date(start), new Date(end)]);
		}

		var ratio = (end - start) / width;
		//console.log(ratio);

		if (ratio < 500) xAxis.tickFormat(d3.timeFormat('%H:%M:%S'));
		else xAxis.tickFormat(d3.timeFormat('%H:%M'));

		svg_xAxis.call(xAxis); // update axis
		svg_graph.attr('d', line); // update graph	
	}
	var zoom = d3.zoom().scaleExtent([1, 24]).translateExtent([[0, 0], [950, 0]]).on('zoom', onzoom);

	svg.call(zoom);

	var onresize = function() {
		scaledWidth = element.getBoundingClientRect().width;
		scaleFactor = scaledWidth / 950;
		zoom.translateExtent([[0, 0], [width * scaleFactor, 0]]);
		onzoom(true);
	}
	window.onresize = onresize;
	onresize();

	this.parseData = function(rawData) {
		data = d3.csvParse(rawData, function(d) {
			var _date = new Date(), array = d.time.split(':');
			_date.setHours(+array[0]);
			_date.setMinutes(+array[1]);
			_date.setSeconds(+array[2]);
			return {
				date: _date,
				temperature: +d.temperature,
				moisture: +d.moisture,
				brightness: +d.brightness,
				carbondioxide: +d.co2
			};
		});
		domainTimeline = d3.extent(data, function(d) { return d.date; });
		scaleX.domain(domainTimeline);
		xAxis = d3.axisBottom(scaleX).tickFormat(d3.timeFormat('%H:%M'));
		svg_xAxis.call(xAxis);
		svg_graph.datum(data);

		this.switchGraph(currentGraph);
		onresize();
 	};

	this.switchGraph = function(newGraph) {
		currentGraph = newGraph;
		//console.log(data);
		var transition = d3.transition().duration(400).ease(d3.easeQuadOut);
		if (newGraph === 'brightness') {
			scaleY.domain([0, 5000]);
		} else if (newGraph === 'temperature') {
			scaleY.domain([0, 40]);
		} else if (newGraph === 'moisture') {
			scaleY.domain([0, 100]);
		} else {
			scaleY.domain([0, 5000]);
		}

		yAxis = d3.axisLeft(scaleY).tickFormat(function(d) { return d+''; });
		svg_yAxis.call(yAxis);

		transition.select('#line-chart-graph').attr('d', line).attr('stroke', colors[currentGraph]);

		svg_axisLabel.text(newGraph);
	}
}
