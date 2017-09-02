/*!
 * @license Open source under BSD 2-clause (http://choosealicense.com/licenses/bsd-2-clause/)
 * Copyright (c) 2015, Curtis Bratton
 * All rights reserved.
 *
 * Liquid Fill Gauge v1.1
 */
function liquidFillGaugeDefaultSettings(){
	return {
		minValue: 0,
		maxValue: 100,
		circleThickness: 0.05,
		circleFillGap: 0.05,
		circleColor: "#178BCA",
		waveHeight: 0.05,
		waveCount: 1,
		waveAnimateTime: 18000,
		waveHeightScaling: true,
		waveAnimate: true,
		waveColor: "#178BCA",
		waveOffset: 0,
		textVertPosition: .5,
		textSize: 0.75,
		valueCountUp: true,
		decimals: 0,
		unit: '%',
		textColor: "#045681",
		waveTextColor: "#A4DBf8"
	};
}

function loadLiquidFillGauge(elementId, value, config) {
	if (config == null) config = liquidFillGaugeDefaultSettings();

	var gauge = d3.select("#" + elementId);
	var radius = 125;
	var fillPercent = Math.max(config.minValue, Math.min(config.maxValue, value))/config.maxValue;

	var waveHeightScale;
	if(config.waveHeightScaling){
		waveHeightScale = d3.scaleLinear()
			.range([0,config.waveHeight,0])
			.domain([0,50,100]);
	} else {
		waveHeightScale = d3.scaleLinear()
			.range([config.waveHeight,config.waveHeight])
			.domain([0,100]);
	}

	var textPixels = (config.textSize*radius/2);
	var textFinalValue = parseFloat(value).toFixed(2);
	var textStartValue = config.valueCountUp?config.minValue:textFinalValue;
	var percentText = config.unit;
	var circleThickness = config.circleThickness * radius;
	var circleFillGap = config.circleFillGap * radius;
	var fillCircleMargin = circleThickness + circleFillGap;
	var fillCircleRadius = radius - fillCircleMargin;
	var waveHeight = fillCircleRadius*waveHeightScale(fillPercent*100);

	var waveLength = fillCircleRadius*2/config.waveCount;
	var waveClipCount = 1+config.waveCount;
	var waveClipWidth = waveLength*waveClipCount;



	// Data for building the clip wave area.
	var data = [];
	for(var i = 0; i <= 40*waveClipCount; i++){
		data.push({x: i/(40*waveClipCount), y: (i/(40))});
	}

	// Scales for drawing the outer circle.
	var gaugeCircleX = d3.scaleLinear().range([0,2*Math.PI]).domain([0,1]);
	var gaugeCircleY = d3.scaleLinear().range([0,radius]).domain([0,radius]);

	// Scales for controlling the size of the clipping path.
	var waveScaleX = d3.scaleLinear().range([0,waveClipWidth]).domain([0,1]);
	var waveScaleY = d3.scaleLinear().range([0,waveHeight]).domain([0,1]);

	// Scales for controlling the position of the clipping path.
	var waveRiseScale = d3.scaleLinear()
		// The clipping area size is the height of the fill circle + the wave height, so we position the clip wave
		// such that the it will overlap the fill circle at all when at 0%, and will totally cover the fill
		// circle at 100%.
		.range([(fillCircleMargin+fillCircleRadius*2+waveHeight),(fillCircleMargin-waveHeight)])
		.domain([0,1]);
	var waveAnimateScale = d3.scaleLinear()
		.range([0, waveClipWidth-fillCircleRadius*2]) // Push the clip area one full wave then snap back.
		.domain([0,1]);

	// Scale for controlling the position of the text within the gauge.
	var textRiseScaleY = d3.scaleLinear()
		.range([fillCircleMargin+fillCircleRadius*2,(fillCircleMargin+textPixels*0.7)])
		.domain([0,1]);

	// Center the gauge within the parent SVG.
	var gaugeGroup = gauge.append("g");

	// Draw the outer circle.
	var gaugeCircleArc = d3.arc()
		.startAngle(gaugeCircleX(0))
		.endAngle(gaugeCircleX(1))
		.outerRadius(gaugeCircleY(radius))
		.innerRadius(gaugeCircleY(radius-circleThickness));
	gaugeGroup.append("path")
		.attr("d", gaugeCircleArc)
		.style("fill", config.circleColor)
		.attr('transform','translate('+radius+','+radius+')');

	// Text where the wave does not overlap.
	var text1 = gaugeGroup.append("text")
		.text(textStartValue + config.unit)
		.attr("class", "liquidFillGaugeText")
		.attr("text-anchor", "middle")
		.attr("font-size", textPixels + "px")
		.style("fill", config.textColor)
		.attr('transform','translate('+radius+','+textRiseScaleY(config.textVertPosition)+')');

	// The clipping wave area.
	var clipArea = d3.area()
		.x(function(d) { return waveScaleX(d.x); } )
		.y0(function(d) { return waveScaleY(Math.sin(Math.PI*2*config.waveOffset*-1 + Math.PI*2*(1-config.waveCount) + d.y*2*Math.PI));} )
		.y1(function(d) { return (fillCircleRadius*2 + waveHeight); } );
	var waveGroup = gaugeGroup.append("defs")
		.append("clipPath")
		.attr("id", "clipWave" + elementId);
	var wave = waveGroup.append("path")
		.datum(data)
		.attr("d", clipArea)
		.attr("T", 0);

	// The inner circle with the clipping wave attached.
	var fillCircleGroup = gaugeGroup.append("g")
		.attr("clip-path", "url(#clipWave" + elementId + ")");
	fillCircleGroup.append("circle")
		.attr("cx", radius)
		.attr("cy", radius)
		.attr("r", fillCircleRadius)
		.style("fill", config.waveColor);

	// Text where the wave does overlap.
	var text2 = fillCircleGroup.append("text")
		.text(textStartValue + config.unit)
		.attr("class", "liquidFillGaugeText")
		.attr("text-anchor", "middle")
		.attr("font-size", textPixels + "px")
		.style("fill", config.waveTextColor)
		.attr('transform','translate('+radius+','+textRiseScaleY(config.textVertPosition)+')');
	var waveGroupXPosition = fillCircleMargin+fillCircleRadius*2-waveClipWidth;
	waveGroup.attr('transform','translate('+waveGroupXPosition+','+waveRiseScale(fillPercent)+')');


	if (config.waveAnimate) animateWave();

	function animateWave() {
		wave.attr('transform','translate('+waveAnimateScale(wave.attr('T'))+',0)');
		wave.transition()
			.duration(config.waveAnimateTime * (1-wave.attr('T')))
			.ease(d3.easeLinear)
			.attr('transform','translate('+waveAnimateScale(1)+',0)')
			.attr('T', 1)
			.on('end', function(){
				wave.attr('T', 0);
				animateWave(config.waveAnimateTime);
			});
	}

	function GaugeUpdater(){
		this.update = function(value){
			var val = value.toFixed(config.decimals);	
		
			text1.text(val + ' ' + config.unit);
			text2.text(val + ' ' + config.unit);

			var fillPercent = (Math.max(config.minValue, Math.min(config.maxValue, value)) - config.minValue)/(config.maxValue - config.minValue);
			var waveHeight = fillCircleRadius*waveHeightScale(fillPercent*100);
			var waveRiseScale = d3.scaleLinear()
				.range([(fillCircleMargin+fillCircleRadius*2+waveHeight),(fillCircleMargin-waveHeight)])
				.domain([0,1]);
			var newHeight = waveRiseScale(fillPercent);
			var waveScaleX = d3.scaleLinear().range([0,waveClipWidth]).domain([0,1]);
			var waveScaleY = d3.scaleLinear().range([0,waveHeight]).domain([0,1]);
			var newClipArea;
			if(config.waveHeightScaling){
				newClipArea = d3.area()
					.x(function(d) { return waveScaleX(d.x); } )
					.y0(function(d) { return waveScaleY(Math.sin(Math.PI*2*config.waveOffset*-1 + Math.PI*2*(1-config.waveCount) + d.y*2*Math.PI));} )
					.y1(function(d) { return (fillCircleRadius*2 + waveHeight); } );
			} else {
				newClipArea = clipArea;
			}

			wave.attr('d', newClipArea);
			waveGroup.attr('transform','translate('+waveGroupXPosition+','+newHeight+')')
		}
	}

	return new GaugeUpdater();
}
