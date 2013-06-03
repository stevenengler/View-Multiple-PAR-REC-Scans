function viewMultipleScansGUI(pathOrFiles)
	% the function can be called with:
	%	0 parameters:
	%		The function will ask the user to select files starting in the
	%		current MATLAB directory
	%	1 parameter:
	%		STRING:
	%			The function will ask the user to select files starting in the
	%			directory specified by the string
	%		CELL ARRAY:
	%			The function will display the image data in the array
	%
	% isPath == 1 if the argument "pathOrFiles" is a path
	% isPath == 0 if the argument "pathOrFiles" is a cell array of scans
	%
	if nargin < 1
		% no parameters
		isPath = 1;
		pathOrFiles = '~';
	else
		% one or more parameters
		if strcmp(class(pathOrFiles),'char')
			% pathOrFiles is a string
			isPath = 1;
		elseif strcmp(class(pathOrFiles),'cell')
			% pathOrFiles is a cell array
			isPath = 0;
		end
	end
	
	if exist('isPath','var')==0
		% if "isPath" was not defined, the supplied argument was neither a string or cell array
		error('Must pass either a string path or a cell array of images scans!');
	end
	
	if isPath==1
		% pathOrFiles is a string (path)
		pathOrFiles = [pathOrFiles,'/'];
		% append a forward slash
		[filenamesUnformatted,pathname] = uigetfile([pathOrFiles,'*.PAR'],'Select *.PAR files','MultiSelect','on');
		% filenames are unformatted because they may be cell arrays or regular arrays
		%
		if iscell(filenamesUnformatted)
			if size(filenamesUnformatted,1) == 0
				% no files selected
				return;
			end
		else
			if filenamesUnformatted == 0
				% no files selected
				return;
			end
		end
		%
		numFiles = size(filenamesUnformatted,iscell(filenamesUnformatted)+1);
		% this works because MATLAB is stupid
		% numFiles = the number of files selected
		%
		images = cell(numFiles,1);
		parms = cell(numFiles,1);
		dims = cell(numFiles,1);
		% cell arrays to hold the images, scan parameters, etc
		%
		filenames = cell(numFiles,1);
		% cell array to hold the filenames
		%
		for i=1:numFiles
			if iscell(filenamesUnformatted)
				% multiple files were selected
				filenames{i} = filenamesUnformatted{i};
			else
				% only one file was selected
				filenames{i} = filenamesUnformatted;
			end
			parfile = [pathname, filenames{i}];
			% the complete file path
			[images{i},parms{i},dims{i}] = GetData_parrec(parfile,'FP');
			% load the scan data in
		end
	else
		% pathOrFiles is a cell array of scan data
		numFiles = size(pathOrFiles,2);
		images = cell(numFiles,1);
		filenames = cell(numFiles,1);
		for i=1:numFiles
			images{i} = pathOrFiles{i};
		end
	end
	%
	mainWindow = figure;
	% the main GUI window
	windowPosition = get(mainWindow,'position');
	% the x, y, width, and height values
	ui_scroll = uicontrol('parent',mainWindow,'Style','Slider','Position',[0 0 windowPosition(3) 20],'tag','ui_scroll');
	% create a scrollbar at the bottom of the window
	%
	for i=1:numFiles
		ui_axes = axes('Parent',mainWindow,'units','pixels');
		% create an axes object for each file to show the images for that file
		colormap(gray);
		% show images in black and white
		set(ui_axes,'visible','off');
		% set the number axes to invisible
		set(ui_axes,'tag',['ui_imageAxes',num2str(i)]);
	end
	%
	set(mainWindow,'ResizeFcn',{@resizeWindow,numFiles});
	% callback for when the main window is resized
	set(ui_scroll,'Callback',{@scrollCallback,numFiles,images,mainWindow,0,1,filenames});
	% callback for when the scrollbar handle is moved
	% will update the images to whatever slice the scrollbar handle is at
	%
	jvscroll = findjobj(ui_scroll);
	jvscroll.MouseDraggedCallback = {@scrollCallback,numFiles,images,mainWindow,jvscroll.getMinimum(),jvscroll.getMaximum(),filenames};
	% to update the images while the sscrollbar handle is being moved, a
	% callback must be added directly to the Java object
	%
	scrollCallback(ui_scroll,0,numFiles,images,mainWindow,0,1,filenames);
	% manually call the scollbar callback to initialize the images
	%
	% success! (hopefully)
end

function resizeWindow(hObject, ~, numFiles)
	% updates the position of the images
	handles = allchild(hObject);
	% gets all the children elements of the window
	ui_scroll = findobj(handles,'Tag','ui_scroll');
	% find the scrollbar handle
	scrollPosition = get(ui_scroll,'position');
	windowPosition = get(hObject,'position');
	% get the scrollbar and window position 
	% the x, y, width, and height values
	scrollPosition(3) = windowPosition(3);
	% update the scrollbar width to the window width
	set(ui_scroll,'position',scrollPosition);
	% update the scrollbar width
	%
	imageSize = 200;
	% the width/height of the images
	for i=1:numFiles
		x = imageSize*mod(i-1,floor(windowPosition(3)/imageSize))+(windowPosition(3)-imageSize*floor(windowPosition(3)/imageSize))/2;
		y = imageSize*floor((i-1)/floor(windowPosition(3)/imageSize))+20;
		% the x and y positions of the current image in the window
		if (isnan(y)~=1)&&(isinf(y)~=1)
			set(findobj(handles,'Tag',['ui_imageAxes',num2str(i)]),'position',[x y imageSize imageSize]);
			% update the position and size of the image
		end
	end
end

function scrollCallback(hObject, ~, numFiles, MR_data, mainWindows, minVal, maxVal, fileNames)
	% update the images to the correct slice of the scan
	handles = allchild(mainWindows);
	% gets all the children elements of the window
	sliderValue = get(hObject, 'value');
	% get the value of the scollbar
	% if the callback is called from matlab, value will be from 0 to 1
	% if the callback is called from Java, value will not be from 0 to 1
	sliderValue = ((sliderValue-minVal)/(maxVal));
	% update the value to a number between 0 and 1
	for i=1:numFiles
		hAxes = findobj(handles,'Tag',['ui_imageAxes',num2str(i)]);
		% get the image axes handle
		hImage = findobj(handles,'Tag',['ui_image',num2str(i)]);
		% get the handle for the image contained in the axes
		slice = round((size(MR_data{i}, 3)-1)*sliderValue)+1;
		% get the slice from the scrollbar value
		if size(hImage,1)==0
			% no image has been loaded yet (window initialization)
			hImage = imagesc(MR_data{i}(:,:,slice),'Parent',hAxes);
			% add the image to the axes
			slices = guidata(hAxes);
			% get the GUI stored slices array
			% this array contains what slice each images is currently on
			slices(i) = slice;
			% update the current image to the current slice
			guidata(hAxes,slices);
			% store the slices array back in the GUI data
			set(hImage, 'Tag', ['ui_image',num2str(i)]);
			% update the tag incase it was overwritten
		else
			sliceOld = guidata(hAxes);
			% get the previous array of current slices
			sliceOld = sliceOld(i);
			% get just the slice value needed
			if slice ~= sliceOld
				% if the image needs to be updated (different slice)
				set(hImage,'CData',MR_data{i}(:,:,slice));
				% update the image to the new slice
				slices = guidata(hAxes);
				% get the old slices again
				slices(i) = slice;
				% update the one slice
				guidata(hAxes,slices);
				% store the slices back in the GUI data
			end
		end
		set(hAxes,'visible','off');
		% set the number axes to invisible
		set(hAxes,'tag',['ui_imageAxes',num2str(i)]);
		% update the tag incase it was overwritten
	end
end
