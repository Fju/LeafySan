'use strict';

const http				= require('http');
const fs				= require('fs');
const WebSocket			= require('ws');
const SerialPort		= require('serialport');
const commandLineArgs	= require('command-line-args')

// -----------------------------
// command line argument parsing
// -----------------------------
const optionDefinitions = [
	{ name: 'list-serial-ports', alias: 'l', type: Boolean },
	{ name: 'serial-port', alias: 's', type: String, defaultValue: '/dev/ttyUSB0' },
	{ name: 'write-data', alias: 'd', type: Boolean },
	{ name: 'http-port', alias: 'h', type: Number, defaultValue: 8000 }
];

const majorVersion	= parseInt(process.version.substr(1).split('.')[0]);


var config = commandLineArgs(optionDefinitions, { partial: true });
if (config['list-serial-ports']) {
	SerialPort.list(function (err, ports) {
		if (err) console.log('Couldn\'t list serial ports');
		ports.forEach(function(port) {
			console.log(port.comName);
			console.log(port.pnpId);
			console.log(port.manufacturer);
		});
	});
} else {
	console.log('Listening to', config['serial-port']);
}

const PROTOCOL_START_CMD			= 0x40; // 0100 0000
const PROTOCOL_DATA_CMD				= 0x80; // 1000 0000
const PROTOCOL_DATA_ALT_CMD			= 0xC0; // 1100 0000
const PROTOCOL_END_CMD				= 0x3F; // 0011 1111
const PROTOCOL_LIGHTING_ID			= 0x00; // 0000 0000
const PROTOCOL_WATERING_ID			= 0x01; // 0000 0001
const PROTOCOL_HEATING_ID			= 0x02; // 0000 0010
const PROTOCOL_CO2_ID				= 0x03; // 0000 0011
const PROTOCOL_LIGHTING_ON_ID		= 0x20; // 0010 0000
const PROTOCOL_WATERING_ON_ID		= 0x10; // 0001 0000
const PROTOCOL_HEATING_ON_ID		= 0x08; // 0000 1000
const PROTOCOL_VENTILATION_ON_ID	= 0x04; // 0000 0100
const PROTOCOL_SEND_BYTES			= 9;	// amount of bytes to be senti

var values = { temp: 0, moisture: 0, brightness: 0, co2: 0, heating: false, watering: false, lighting: false, ventilation: false };
var thresholds = { temp: 21.0, moisture: 50.0, brightness: 60 };

var port = new SerialPort(config['serial-port'], { baudRate: 115200 }),
	started, completeData, prevCmd, bitShift, index;
port.on('error', (err) => {
	console.log('Error: Something went wrong reading the serial port!\n' + err);
});
port.on('data', (data) => {
	data.forEach((element) => {
		if (element === PROTOCOL_START_CMD) {
			started = true;
			prevCmd = 0;
			bitShift = 0;
			index = 0;
			completeData = [];
		} else if (element === PROTOCOL_END_CMD) {
			started = false;
			if (completeData.length !== 0) {
				// parse dataset
				var i, item;
				for (i = 0; i != completeData.length; ++i) {
					item = completeData[i];
					if (i === PROTOCOL_LIGHTING_ID) {
						values.brightness = item >> 2;
					} else if (i === PROTOCOL_WATERING_ID) {
						values.moisture = item >> 2;
					} else if (i === PROTOCOL_HEATING_ID) {
						values.temp = item >> 2;
					} else if (i === PROTOCOL_CO2_ID) {
						values.co2 = item >> 2;
					} else {
						item = item >> 12; // we only need the last 6 bit
						values.heating = (item & PROTOCOL_HEATING_ON_ID) > 0;
						values.watering = (item & PROTOCOL_WATERING_ON_ID) > 0;
						values.lighting = (item & PROTOCOL_LIGHTING_ON_ID) > 0;
						values.ventilation = (item & PROTOCOL_VENTILATION_ON_ID) > 0;
					}
				}
			} else console.log('Received invalid dataset :/');
		} else if (started) {
			var newCmd = (element & 0xC0) >> 6;
			if (!prevCmd) prevCmd = newCmd;
			if (prevCmd !== newCmd) {
				bitShift = 0;
				index++;
				prevCmd = newCmd;
			}
			if (index <= 4) completeData[index] = completeData[index] | ((element & 0x3F) << (6 * (2-bitShift++)));
		}
	});
});

setInterval(function() {
	var buf, s = 0, i, shift = 0, prefix, data, value;

	if (majorVersion >= 6) {
		// Buffer.from was introduced in Node.js v6.0.0
		buf = Buffer.from([PROTOCOL_START_CMD, 0, 0, 0, 0, 0, 0, 0, 0, 0, PROTOCOL_END_CMD]);
	} else {
		// use (depricated) fallback in older versions
		buf = new Buffer([PROTOCOL_START_CMD, 0, 0, 0, 0, 0, 0, 0, 0, 0, PROTOCOL_END_CMD]);
	}

	for (i = 0; i != PROTOCOL_SEND_BYTES; ++i) {
		if (s % 2 === 0) prefix = PROTOCOL_DATA_CMD;
		else prefix = PROTOCOL_DATA_ALT_CMD;

		if (s === PROTOCOL_LIGHTING_ID) value = thresholds.brightness;
		else if (s === PROTOCOL_WATERING_ID) value = Math.floor(thresholds.moisture * 10);
		else if (s === PROTOCOL_HEATING_ID) value = Math.floor(thresholds.temp * 10);

		if (shift === 2) data = ((value & 0x0F) << 2) | s;
		else data = (value >> (4 + (1-shift) * 6)) & 0x3F;
		buf.writeUInt8(prefix | data, 1 + i);

		if (i % 3 === 2) {
			//reset shift, move to next threshold value
			shift = 0;
			s++;
		} else shift++;
	}
	// send thresholds to DE2-Board
	port.write(buf);

	if (!config['write-data']) return; // don't write data

	var date = new Date(),
		path = 'data/data_' + date.getFullYear() + '-' + (1+date.getMonth()) + '-' + date.getDate() + '.csv',
		v = {
			t: (values.temp * 0.1).toFixed(1),
			m: (values.moisture * 0.1).toFixed(1),
			b: values.brightness,
			c: values.co2,
			h: values.heating * 1,
			w: values.watering * 1,
			l: values.lighting * 1,
			v: values.ventilation * 1
		},
		d = date.getHours() + ':' + date.getMinutes() + ':' + date.getSeconds();

	fs.readFile(path, 'utf-8', (err, fileContent) => {
		if (err) fileContent = 'time,temperature,moisture,brightness,co2,heating,watering,lighting,ventilation\n'; // write csv header
		value = ([d, v.t, v.m, v.b, v.c, v.h, v.w, v.l, v.v]).join(',');
		fs.writeFile(path, fileContent + value + '\n', (err) => {
			if (err) throw err;
			console.log('written', path, value);
		});
	});
}, 1000);

let server = http.createServer((req, res) => {
	var url = req.url;

	//beautify URL, shows foo.bar when requested foo.bar/index.html
	if (url === '/index.html') {
		res.writeHead(301, {'Location': '/'});
		res.end();
		return;
	}
	if (url === '/') {
		url = '/index.html';
	}
	fs.readFile('./www' + url, (err, data) => {
		if (err) {
			res.writeHead(404);
			res.end('Error 404:\nPage not found\n');
		} else {
			let extension = url.slice(url.lastIndexOf('.') - url.length + 1);
			let mimeList = { html: 'text/html', less: 'text/css', css: 'text/css', svg: 'image/svg+xml', png: 'image/png', js: 'application/javascript' },
				mime = 'application/octet-stream';

			if (extension in mimeList) mime = mimeList[extension];

			res.writeHead(200, {'Content-Type': mime});
			res.end(data);
		}
	});
});
server.listen(config['http-port']);


const wss = new WebSocket.Server({ port: 8080 });

wss.on('connection', (ws, req) => {

	ws.on('message', (message) => {
		let json = JSON.parse(message);
		//console.log(message);
		if (json.type === 'values') {
			ws.send(JSON.stringify({
				type: 'values',
				data: {
					brightness: values.brightness,
					moisture: (values.moisture * 0.1).toFixed(1),
					temperature: (values.temp * 0.1).toFixed(1),
					co2: values.co2,
					heating: values.heating * 1,
					watering: values.watering * 1,
					lighting: values.lighting * 1,
					ventilation: values.ventilation * 1
				}
			}));
		} else if (json.type === 'archive') {
			var archivePath = 'data_test.csv';
			if (json.date > 0) {
				var date = new Date(json.date);
				var archivePath = 'data_' + date.getFullYear() + '-' + (1+date.getMonth()) + '-' + date.getDate() + '.csv';
			}
			fs.readFile('data/' + archivePath, 'utf-8', (err, data) => {
				if (err) data = '';
				var array = data.split('\n'), header = array[0], x = 0, i = 0, ratio;
				array.splice(0, 1);
				if (array.length > 1000) {
					ratio = 1000 / array.length;
					while (x < array.length) {
						i = (i + ratio) % 1;
						if (i < ratio) x++;
						else array.splice(x, 1);
					}
				}
				array.unshift(header);
				console.log(array.length);
				ws.send(JSON.stringify({
					type: 'archive',
					data: array.join('\n')
				}));
			});
		} else if (json.type === 'thresholds') {
			var a = json.data.temperature, b = json.data.moisture, c = json.data.brightness;
			console.log(a, b, c, json);
			if (!isNaN(a) && a >= 0 && a <= 30) thresholds.temp = Math.round(a * 10) / 10;
			if (!isNaN(b) && b >= 0 && b <= 100) thresholds.moisture = Math.round(b * 10) / 10;
			if (!isNaN(c) && c >= 0 && c <= 40000) thresholds.brightness = Math.round(c);
			console.log('Thresholds', thresholds);
		}
	});
});
