

Views.Timeline = React.createClass
	mixins: [ReactUtils]
	ranges:
		Today: [
			moment().format(Constants.dateFormat)
			moment().format(Constants.dateFormat)
		]
		"Last 2 Days": [
			moment().subtract(2, 'days').format(Constants.dateFormat)
			moment().subtract(1, 'day').format(Constants.dateFormat)
		]
		"Last 7 Days": [
			moment().subtract(7, 'days').format(Constants.dateFormat)
			moment().subtract(1, 'days').format(Constants.dateFormat)
		]
		"Last month": [
			moment().subtract(1, 'month').format(Constants.dateFormat)
			moment().subtract(1, 'days').format(Constants.dateFormat)
		]
		"Last 3 months": [
			moment().subtract(3, "months").format(Constants.dateFormat)
			moment().subtract(1, 'days').format(Constants.dateFormat)
		]
		"Last 6 months": [
			moment().subtract(6, "months").format(Constants.dateFormat)
			moment().subtract(1, 'days').format(Constants.dateFormat)
		]
	views:
		logs: "Events"
		users: "Users"
		devices: "Devices"
		sessions: "Sessions"
		timeOnline: "Time online"
		averageTimeOnline: "Average time online"
		deviceTypes: "Device types"
		browsers: "Browsers"
		browserVersions: "Browser versions"
		oses: "Operating systems"
		locations: "Unique locations"
	granularities:
		auto: "Auto"
		day: "Day"
		week: "Week"
		month: "Month"
	logTypes:
		view: "View"
		connected: "Connected"
		location: "Location"
		login: "Log in"
		logout: "Log out"
		update: "Update"
		online: "Online"
		"user-detected": "User detected"
	browserViews:
		views: "views"
		devices: "devices"
		versions: "versions"
		users: "users"
	locationViews:
		views: "views"
		users: "users"
		timeOnline: "time online"
		combinedViewsRatio: "combined views ratio"
	userViews:
		views: "views"
		timeOnline: "time online"
		devices: "devices"
		combinedDevices: "max combined devices"
	deviceCombinationViews:
		users: "users"
		views: "views"
	timeline: null
	chart: null
	currentChart: null
	labels: []
	deviceTypes: ["sm", "md", "lg", "xl"]

	getInitialState: ->
		from: moment().startOf('day').subtract(7, 'days').toDate()
		to: moment().endOf('day').subtract(1, 'days').toDate()
		granularity: 'auto'

		# Filter lists
		locations: null
		browsers: null
		oses: null
		users: null
		deviceCombinations: null
		deviceTypes: null
		deviceTypeCombinations: null
		devices: null
		pattern: ""
		patterns: []

		values: {}

		view: "logs"

		views:
			locations: "views"
			users: "views"
			browsers: "views"
			deviceCombinations: "users"

		filter: null

		filters:
			logType: "view"

	filterValueLabel: (key, value) ->
		switch key
			when "deviceType"
				value = @deviceTypes[value-1]
			when "deviceTypeCombination"
				combination = for type in value
					@deviceTypes[type-1]
				value = combination.join("-")
			when "locationCombination"
				value = value.join("-")
			when "osCombination"
				value = value.join("-")
			when "browserCombination"
				value = value.join("-")
		value

	currentSelectionLabel: ->
		label = @views[@state.view]
		parts = []
		for key, value of @state.filters
			value = @filterValueLabel key, value
			parts.push "#{key}: #{value}"
		if parts.length
			label += " (#{parts.join(", ")})"

		label
	addDataset: ->
		options = {}
		for key, value of @state.filters
			options[key] = value
		data =
			view: @state.view
			options: options
		@setValueSet @currentSelectionLabel(), data
	setValueSet: (label, data) ->
		self = @
		values = @state.values
		data.color = colorPair 0.5
		if values[label]
			delete(values[label])
			@setState
				values: values
			, ->
				if !self.state.filter
					self.lineChart()
		else
			values[label] = data
			@setState
				values: values
			, @wrap(@loadDataset, label)
	componentDidMount: ->
		@timeline = document.getElementById("timeline")
		@addDataset()
		@loadAllValues()
	setView: (name, value) ->
		self = @
		set = {}
		set.views = @state.views
		set.views[name] = value
		@setState set
		, ->
			self.loadValues name
	loadAllValues: ->
		log "Load all values"
		@loadAllDatasets()
		@loadAllFilters()
	loadAllDatasets: ->
		self = @
		values = @state.values
		for label, data of values
			delete(data.values)
		@setState
			values: values
		, ->
			if !self.state.filter
				self.lineChart()
			for label, data of self.state.values
				self.loadDataset label
	loadAllFilters: ->
		@loadValues "deviceTypes"
		@loadValues "deviceCombinations"
		@loadValues "deviceTypeCombinations"
		@loadValues "browsers"
		@loadValues "browserCombinations"
		@loadValues "oses"
		@loadValues "osCombinations"
		@loadValues "locations"
		@loadValues "locationCombinations"
		@loadValues "users"
		@loadValues "devices"
	loadValues: (view) ->
		order = @state.views[view]
		self = @
		set = {}
		set[view] = null
		self.setState set, ->
			if self.state.filter is view
				self.barChart()
			Meteor.call 'getAggregatedValues', self.props.appId, view, order, self.state.from, self.state.to, self.state.filters, handleResult null, (r) ->
				set = {}
				set[view] = r
				self.setState set, ->
					if self.state.filter is view
						self.barChart()
	deleteValue: (label) ->
		self = @
		values = @state.values
		delete(values[label])
		@setState
			values: values
		, ->
			if !self.state.filter
				self.lineChart()
	loadDataset: (label) ->
		data = @state.values[label]
		view = data.view
		options = data.options
		self = @
		Meteor.call 'getAnalyticsValues', @props.appId, view, @state.from, @state.to, options, @state.granularity, handleResult null, (r) ->
			[labels, values] = r
			self.labels = labels
			allValues = self.state.values
			if allValues[label]?
				allValues[label].values = values
				self.setState
					values: allValues
				, ->
					if !self.state.filter
						self.lineChart()
	addPattern: ->
		pattern = @state.pattern
		patterns = @state.patterns
		patterns.push pattern
		@setState
			patterns: patterns
			pattern: ""
	toggleFilter: (filter) ->
		self = @
		@setState
			filter: if @state.filter is filter then null else filter
		, ->
			if @state.filter
				self.barChart()
			else
				self.lineChart()
	barChart: ->

		labels = []
		datasets = []

		if @state[@state.filter]
			data = []
			for datum in @state[@state.filter]
				switch @state.filter
					when "deviceTypes"
						label = @deviceTypes[datum._id-1]
					when "deviceTypeCombinations"
						types = for type in datum._id
							@deviceTypes[type-1]
						label = types.join(",")
					when "locations"
						label = cut(datum._id, 20)
					when "locationCombinations"
						locations = for location in datum._id
							cut(location, 10)
						label = locations.join(",")
					else
						label = cut(datum._id, 10)
				labels.push label
				data.push datum.count
			[color, lighter] = colorPair 0.5

			datasets.push
				label: @state.filter
				data: data
				fillColor: lighter
				strokeColor: color
				highlightFill: lighter
				highlightStroke: color

		if @currentChart
			@currentChart.destroy()
		ctx = @timeline.getContext("2d")

		@chart = new Chart(ctx)
		@currentChart = @chart.Bar
			labels: labels
			datasets: datasets
		,
			multiTooltipTemplate: "<%= datasetLabel %> - <%= value %>"
	lineChart: ->
		log @state.values
		labels = @labels
		datasets = []
		if Object.keys(@state.values).length
			for label, data of @state.values
				[color, lighter] = data.color

				dataset =
					label: label
					data: data.values
					fillColor: lighter
					strokeColor: color
					pointColor: color
					pointStrokeColor: "white"
					pointHighlightStroke: color

				datasets.push dataset
		else
			datasets.push
				label: "No data"

		if @currentChart
			@currentChart.destroy()
		ctx = @timeline.getContext("2d")

		@chart = new Chart(ctx)
		@currentChart = @chart.Line
			labels: labels
			datasets: datasets
		,
			multiTooltipTemplate: (valuesObject) ->
				"#{cut(valuesObject.datasetLabel, 30)} - #{valuesObject.value}"
			bezierCurve: false
	clearCache: ->
		Meteor.call 'clearCache', @props.appId, handleResult "Cache cleared"
	setBrowser: (browser) ->
		filters = @state.filters
		if filters.browser is browser
			delete(filters.browser)
		else
			filters.browser = browser
		delete(filters.browserVersion)
		@setState
			filters: filters
	setBrowserVersion: (browser, browserVersion)->
		filters = @state.filters
		if filters.browser is browser and filters.browserVersion is browserVersion
			delete(filters.browserVersion)
		else
			filters.browser = browser
			filters.browserVersion = browserVersion
		@setState
			filters: filters
	render: ->
		<div>
			<div>
				<div className="col-xs-12 col-sm-4">
					<Templates.DateRangeInput id="range" label="Time range" from={@state.from} to={@state.to} ranges={@ranges} onChange={@updateRange("from","to", @loadAllValues)} time={true}/>
				</div>
				<div className="col-xs-12 col-sm-4">
					<Templates.Select id="granularity" label="Granularity" options={@granularities} value={@state.granularity} onChange={@updateValue('granularity', @loadAllDatasets)}/>
				</div>
				<div className="col-xs-12 col-sm-4">
					<button className="btn btn-default" onClick={@loadAllDatasets}>
						Refresh data
					</button>
					&nbsp;
					<button onClick={@loadAllFilters} className="btn btn-default">
						Refresh filters
					</button>
					&nbsp;
					<button className="btn btn-default" onClick={@clearCache}>
						Clear cache
					</button>
				</div>
			</div>
			<div>
				<div className="col-xs-12 col-sm-9">
					<div id="timeline-wrapper">
						<canvas id="timeline" height="80"></canvas>
					</div>
				</div>
				<div className="col-xs-12 col-sm-3">
					<h3>Data</h3>
					{
						if @state.filter
							<div>{@state.filter}</div>
							<button className="btn btn-primary" onClick={@setValue("filter", null, @lineChart)}>Back to timeline</button>
					}
					<h4>Current</h4>
					{
						if Object.keys(@state.values).length
							<ul>
								{
									for label, data of @state.values
										<li key={label}>
											{
												if data.values
													total = 0
													for value in data.values
														total += value
													if data.view is "averageTimeOnline"
														total /= data.values.length
													<span style={{color: data.color[0]}}>
														{condFixed(total)}
														&nbsp;
													</span>
												else
													<span>
														<Templates.Spinner/>
														&nbsp;
													</span>
											}
											<span style={{color: data.color[0]}} title={label}>
												{label}
											</span>
											&nbsp;
											<button className="btn btn-danger btn-xs" onClick={@wrap(@deleteValue,label)}>
												<i className="fa fa-remove"></i>
											</button>
										</li>
								}
							</ul>
						else
							<p>No data selected.</p>
					}
					<h4>Selection</h4>
					<span>{@views[@state.view]}</span>
					<ul>
						{
							for key, value of @state.filters
								<li key={key}>
									<span>{key}: {@filterValueLabel(key, value)}</span>
									&nbsp;
									<button onClick={@unsetDictValue("filters", key)} className="btn btn-danger btn-xs">
										<i className="fa fa-remove"></i>
									</button>
								</li>
						}
					</ul>
					{
						if @state.values[@currentSelectionLabel()]
							<button onClick={@addDataset} className="btn btn-primary btn-md">
								Remove from data
							</button>
						else
							<button onClick={@addDataset} className="btn btn-primary btn-md">
								Add to data
							</button>
					}
				</div>
			</div>
			<div>
				<div className="col-xs-12">
					<h3>Select</h3>
					<div className="labels">
						{
							for name, label of @views
								<label key={name} className={"#{if @state.view is name then "active"}"} onClick={@setValue('view',name)}>{label}</label>
						}
					</div>
				</div>
			</div>
			<div>
				<div className="col-xs-12">
					<h3>Filter</h3>
				</div>
			</div>
			<div>
				<div className="col-xs-12 col-sm-3 col-lg-2">
					<h4>Event types</h4>
					<ul className="activables">
						{
							for logType, label of @logTypes
								<li key={logType}>
									<a onClick={@toggleDictValue("filters", "logType", logType)} className={if @state.filters.logType is logType then "active"}>{label}</a>
								</li>
						}
					</ul>
				</div>
				<div className="col-xs-12 col-sm-3 col-lg-2">
					<h3>Devices</h3>
					<h4>
						Types
						&nbsp;
						<button className="btn btn-xs btn-default" onClick={@wrap(@loadValues,"deviceTypes")}>
							<i className="fa fa-refresh"></i>
						</button>
						&nbsp;
						<button className="btn btn-xs btn-default" onClick={@wrap(@toggleFilter, "deviceTypes")}>
							<i className="fa fa-bar-chart"></i>
						</button>
					</h4>
					{
						if @state.deviceTypes
							<ul className="activables">
								{
									for deviceType, i in @state.deviceTypes
										<li key={i}>
											<a onClick={@toggleDictValue("filters", "deviceType", deviceType._id)} className={if @state.filters.deviceType is deviceType._id then "active"}>
												{@deviceTypes[deviceType._id-1] or "undefined"} ({deviceType.count} devices)
											</a>
										</li>
								}
							</ul>
						else
							<Templates.Loading/>
					}
					<h4>
						Amount
						&nbsp;
						<button className="btn btn-xs btn-default" onClick={@wrap(@loadValues,"deviceCombinations")}>
							<i className="fa fa-refresh"></i>
						</button>
						&nbsp;
						<button className="btn btn-xs btn-default" onClick={@wrap(@toggleFilter, "deviceCombinations")}>
							<i className="fa fa-bar-chart"></i>
						</button>
					</h4>
					<div className="labels">
						Sort by
						{
							for name, label of @deviceCombinationViews
								<label key={name} onClick={@wrap(@setView, 'deviceCombinations', name)} className={if @state.views.deviceCombinations is name then "active"}>{label}</label>
						}
					</div>
					{
						if @state.deviceCombinations
							<ul className="activables">
								{
									for deviceCount, i in @state.deviceCombinations
										active = false
										if @state.filters.deviceCount is deviceCount._id
											active = true
										<li key={i} >
											<a onClick={@toggleDictValue("filters", "deviceCount", deviceCount._id)} className={if active then "active"}>
												{deviceCount._id or "undefined"} ({deviceCount.count})
											</a>
										</li>
								}
							</ul>
						else
							<Templates.Loading/>
					}
					<h4>
						Combinations
						&nbsp;
						<button className="btn btn-xs btn-default" onClick={@wrap(@loadValues,"deviceTypeCombinations")}>
							<i className="fa fa-refresh"></i>
						</button>
						&nbsp;
						<button className="btn btn-xs btn-default" onClick={@wrap(@toggleFilter, "deviceTypeCombinations")}>
							<i className="fa fa-bar-chart"></i>
						</button>
					</h4>
					{
						if @state.deviceTypeCombinations
							if @state.filters.deviceTypeCombination
								activeCombination = for type in @state.filters.deviceTypeCombination
									@deviceTypes[type-1]
								activeLabel = activeCombination.join(", ")
							<ul className="activables">
								{
									for deviceTypeCombination, i in @state.deviceTypeCombinations
										combination = for type in deviceTypeCombination._id
											@deviceTypes[type-1]
										label = combination.join(", ")
										<li key={i}>
											<a className={if label is activeLabel then "active"} onClick={@toggleDictValue("filters", "deviceTypeCombination", deviceTypeCombination._id)}>
												{label or "undefined"} ({deviceTypeCombination.count} users)
											</a>
										</li>
								}
							</ul>
						else
							<Templates.Loading/>
					}
				</div>
				<div className="col-xs-12 col-sm-3 col-lg-2">
					<h4>
						Browsers
						&nbsp;
						<button className="btn btn-xs btn-default" onClick={@wrap(@loadValues,"browsers")}>
							<i className="fa fa-refresh"></i>
						</button>
						&nbsp;
						<button className="btn btn-xs btn-default" onClick={@wrap(@toggleFilter, "browsers")}>
							<i className="fa fa-bar-chart"></i>
						</button>
					</h4>
					<div className="labels">
						sort by
						{
							for name, label of @browserViews
								<label key={name} onClick={@wrap(@setView, 'browsers', name)} className={if @state.views.browsers is name then "active"}>{label}</label>
						}
					</div>
					{
						if @state.browsers
							<ul className="activables">
								{
									for browser, i in @state.browsers
										<li key={i} >
											<Templates.Dropdown>
												<a onClick={@wrap(@setBrowser,browser._id)} className={if @state.filters.browser is browser._id then "active"}>
													{browser._id or "undefined"} ({browser.count})
												</a>
												<ul>
													{
														for version, j in browser.versions
															<li key={j}>
																<a onClick={@wrap(@setBrowserVersion,browser._id, version.version)} className={if @state.filters.browser is browser._id and @state.filters.browserVersion is version.version then "active"}>
																	{version.version or "undefined"}
																	({version.count})
																</a>
															</li>
													}
												</ul>
											</Templates.Dropdown>
										</li>
								}
							</ul>
						else
							<Templates.Loading/>
					}
					<h4>
						Browser combinations
						&nbsp;
						<button className="btn btn-xs btn-default" onClick={@wrap(@loadValues,"browserCombinations")}>
							<i className="fa fa-refresh"></i>
						</button>
						&nbsp;
						<button className="btn btn-xs btn-default" onClick={@wrap(@toggleFilter, "browserCombinations")}>
							<i className="fa fa-bar-chart"></i>
						</button>
					</h4>
					{
						if @state.browserCombinations
							if @state.filters.browserCombination
								activeLabel = @state.filters.browserCombination.join(", ")
							<ul className="activables">
								{
									for browserCombination, i in @state.browserCombinations
										label = browserCombination._id.join(", ")
										<li key={i}>
											<a className={if label is activeLabel then "active"} onClick={@toggleDictValue("filters", "browserCombination", browserCombination._id)}>
												{label or "undefined"} ({browserCombination.count} users)
											</a>
										</li>
								}
							</ul>
						else
							<Templates.Loading/>
					}
					<h4>
						Operating systems
						&nbsp;
						<button className="btn btn-xs btn-default" onClick={@wrap(@loadValues,"oses")}>
							<i className="fa fa-refresh"></i>
						</button>
						&nbsp;
						<button className="btn btn-xs btn-default" onClick={@wrap(@toggleFilter, "oses")}>
							<i className="fa fa-bar-chart"></i>
						</button>
					</h4>
					{
						if @state.oses
							<ul className="activables">
								{
									for os, i in @state.oses
										<li key={i} >
											<a onClick={@toggleDictValue("filters", "os", os._id)} className={if @state.filters.os is os._id then "active"}>
												{os._id or "undefined"} ({os.count} devices)
											</a>
										</li>
								}
							</ul>
						else
							<Templates.Loading/>
					}
					<h4>
						OS combinations
						&nbsp;
						<button className="btn btn-xs btn-default" onClick={@wrap(@loadValues,"osCombinations")}>
							<i className="fa fa-refresh"></i>
						</button>
						&nbsp;
						<button className="btn btn-xs btn-default" onClick={@wrap(@toggleFilter, "osCombinations")}>
							<i className="fa fa-bar-chart"></i>
						</button>
					</h4>
					{
						if @state.osCombinations
							if @state.filters.osCombination
								activeLabel = @state.filters.osCombination.join(", ")
							<ul className="activables">
								{
									for osCombination, i in @state.osCombinations
										label = osCombination._id.join(", ")
										<li key={i}>
											<a className={if label is activeLabel then "active"} onClick={@toggleDictValue("filters", "osCombination", osCombination._id)}>
												{label or "undefined"} ({osCombination.count} users)
											</a>
										</li>
								}
							</ul>
						else
							<Templates.Loading/>
					}
				</div>
				<div className="col-xs-12 col-sm-3 col-lg-2">
					<h4>
						Locations
						&nbsp;
						<button className="btn btn-xs btn-default" onClick={@wrap(@loadValues,"locations")}>
							<i className="fa fa-refresh"></i>
						</button>
						&nbsp;
						<button className="btn btn-xs btn-default" onClick={@wrap(@toggleFilter, "locations")}>
							<i className="fa fa-bar-chart"></i>
						</button>
					</h4>
					<div className="labels">
						sort by
						{
							for name, label of @locationViews
								<label key={name} onClick={@wrap(@setView, "locations", name)} className={if @state.views.locations is name then "active"}>{label}</label>
						}
					</div>
					<div className="form-group">
						<div className="input-group">
							<input type="text" className="form-control" value={@state.pattern} onChange={@updateValue('pattern')} onKeyDown={@onEnter(@addPattern)} placeholder="Add a location (pattern)"/>
							<span className="input-group-btn">
								<button className="btn btn-primary" onClick={@addPattern}>
									<i className="fa fa-plus"></i>
								</button>
							</span>
						</div>
					</div>
					<ul className="activables">
						{
							for pattern, i in @state.patterns
								<li key={i}>
									<a onClick={@toggleDictValue("filters", "locationPattern", pattern)} className={if @state.filters.locationPattern is pattern then "active"}>
										{pattern}
									</a>
								</li>
						}
					</ul>
					{
						if @state.locations
							<ul className="activables">
								{
									for location, i in @state.locations
										active = @state.filters.location is location._id
										switch @state.views.locations
											when "timeOnline"
												count = formatInterval location.count
											else
												count = location.count
										<li key={i}>
											<a onClick={@toggleDictValue("filters", "location", location._id)} className={if  active then "active"} title={location._id}>
												{if active then location._id else cut(location._id,25)} ({count})
											</a>
										</li>
								}
							</ul>
						else
							<Templates.Loading/>
					}
					<h4>
						Location combinations
						&nbsp;
						<button className="btn btn-xs btn-default" onClick={@wrap(@loadValues,"locationCombinations")}>
							<i className="fa fa-refresh"></i>
						</button>
						&nbsp;
						<button className="btn btn-xs btn-default" onClick={@wrap(@toggleFilter, "locationCombinations")}>
							<i className="fa fa-bar-chart"></i>
						</button>
					</h4>
					{
						if @state.locationCombinations
							if @state.filters.locationCombination
								activeLabel = @state.filters.locationCombination.join(", ")
							<ul className="activables">
								{
									for locationCombination, i in @state.locationCombinations
										combination = []
										for loc in locationCombination._id
											combination.push cut(loc, 12)
										label = combination.join(", ")
										fullLabel = locationCombination._id.join(", ")
										active = fullLabel is activeLabel
										<li key={i}>
											<a className={if active then "active"} title={fullLabel} onClick={@toggleDictValue("filters", "locationCombination", locationCombination._id)}>
												{if active then fullLabel else label or "undefined"} ({locationCombination.count} users)
											</a>
										</li>
								}
							</ul>
						else
							<Templates.Loading/>
					}
				</div>
				<div className="col-xs-12 col-sm-3 col-lg-2">
					<h4>
						Users
						&nbsp;
						<button className="btn btn-xs btn-default" onClick={@wrap(@loadValues,"users")}>
							<i className="fa fa-refresh"></i>
						</button>
						&nbsp;
						<button className="btn btn-xs btn-default" onClick={@wrap(@toggleFilter, "users")}>
							<i className="fa fa-bar-chart"></i>
						</button>
					</h4>
					<div className="labels">
						sort by
						{
							for name, label of @userViews
								<label key={name} onClick={@wrap(@setView, "users", name)} className={if @state.views.users is name then "active"}>{label}</label>
						}
					</div>
					{
						if @state.users
							<ul className="activables">
								{
									for user, i in @state.users
										active = @state.filters.user is user._id
										switch @state.views.users
											when "timeOnline", "combinedTimeOnline"
												count = formatInterval user.count
											else
												count = user.count
										<li key={user._id}>
											<a onClick={@toggleDictValue("filters", "user", user._id)} className={if active then "active"} title={user._id}>
												{if active then user._id else cut(user._id,20) or "undefined"} ({count})
											</a>
										</li>
								}
							</ul>
						else
							<Templates.Loading/>
					}
				</div>
				<div className="col-xs-12 col-sm-3 col-lg-2">
					<h4>
						Devices
						&nbsp;
						<button className="btn btn-xs btn-default" onClick={@wrap(@loadValues,"devices")}>
							<i className="fa fa-refresh"></i>
						</button>
						&nbsp;
						<button className="btn btn-xs btn-default" onClick={@wrap(@toggleFilter, "devices")}>
							<i className="fa fa-bar-chart"></i>
						</button>
					</h4>
					{
						if @state.devices
							<ul className="activables">
								{
									for device, i in @state.devices
										active = @state.filters.device is device._id
										<li key={device._id}>
											<a onClick={@toggleDictValue("filters", "device", device._id)} className={if active then "active"} title={device._id}>
												{if active then device._id else cut(device._id,20) or "undefined"} ({device.count} views)
											</a>
										</li>
								}
							</ul>
						else
							<Templates.Loading/>
					}
				</div>
			</div>
		</div>

# Some utility functions

colorPair = (alpha) ->
		color = [Math.floor(Math.random()*256), Math.floor(Math.random()*256), Math.floor(Math.random()*256)]

		lighten = 20

		highlight = [Math.min(color[0] + lighten, 255), Math.min(color[1] + lighten, 255), Math.min(color[2] + lighten, 255)]

		[rgba(color), rgba(highlight, alpha)]

colorPairSeries = (amount, alpha) ->

	colors = []
	i = 0

	base = [Math.random()*100, Math.random()*100, Math.random()*100]

	lighten = 20

	max = 255 - 40

	min = Math.max base[0], base[1], base[2]

	gap = (max - min) / amount

	while i < amount
		color = [base[0] + i*gap, base[1] + i*gap, base[2] + i*gap]
		highlight = [Math.min(color[0] + lighten, 255), Math.min(color[1] + lighten, 255), Math.min(color[2] + lighten, 255)]
		colors[i] = [rgba(color), rgba(highlight, alpha)]
		i++

	colors

rgba = (color, alpha) ->
	if !alpha?
		alpha = 1
	"rgba(#{Math.floor(color[0])},#{Math.floor(color[1])},#{Math.floor(color[2])},#{alpha})"

cut = (string, length) ->
	if string?.length > length
		"#{string[0...length/2]}...#{string[-length/2..]}"
	else
		string

formatInterval = (ms) ->
	if ms < 1000
		return "#{ms} ms"
	ms /= 1000

	if ms < 60
		return "#{ms.toFixed(1)} s"
	ms /= 60

	if ms < 60
		return "#{ms.toFixed(1)} m"
	ms /= 60

	if ms < 24
		return "#{ms.toFixed(1)} h"
	ms /= 24

	if ms < 365
		return "#{ms.toFixed(1)} d"

	ms /= 365
	return "#{ms.toFixed(1)} y"

condFixed = (n) ->
	if Math.floor(n) isnt n
		n.toFixed(1)
	else
		n
