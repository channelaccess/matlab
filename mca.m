function varargout = mca(commandswitch, varargin)

%% create CA context if non existent
global context;
if isempty(context)
    javaaddpath('./ca_matlab-1.0.0.jar');
    disp('Add matlab jar');
    % Use EPICS CA configuration from evironment variables
    properties = java.util.Properties();
    properties.setProperty('EPICS_CA_ADDR_LIST', getenv('EPICS_CA_ADDR_LIST'));
    properties.setProperty('EPICS_CA_AUTO_ADDR_LIST', getenv('EPICS_CA_AUTO_ADDR_LIST'));
    properties.setProperty('EPICS_CA_CONN_TMO', getenv('EPICS_CA_CONN_TMO'));
    properties.setProperty('EPICS_CA_BEACON_PERIOD', getenv('EPICS_CA_BEACON_PERIOD'));
    properties.setProperty('EPICS_CA_REPEATER_PORT', getenv('EPICS_CA_REPEATER_PORT'));
    properties.setProperty('EPICS_CA_SERVER_PORT', getenv('EPICS_CA_SERVER_PORT'));
    properties.setProperty('EPICS_CA_MAX_ARRAY_BYTES', getenv('EPICS_CA_MAX_ARRAY_BYTES'));
    context = javaObjectEDT('ch.psi.jcae.Context', properties);
    disp('MCA initialized');
end

%% call function table
if nargin == 0
    error('Please provide function index number');
end

global channel_table
if isempty(channel_table)
    channel_table = containers.Map('KeyType','int32','ValueType','any');
end
    
switch (commandswitch)
    case -1
        varargout{1} = '5.0.0.TEST';
    case 0
        % mcaunlock is not necessary
    
    case 1  % mcaopen PVName1, PVName2, ...
        if ischar(varargin)
            lens = 1;
            params = {varargin};
        else
            lens = length(varargin);
            params = varargin;
        end
        channels = num2cell(zeros(1, lens));
        for i=1:lens
            PVName = params{i};
            channels{i} = addChannel(PVName);
        end
        varargout = channels;
    
    case 2  % mcaopen {PVName1, PVName2}
        params = varargin{1};
        lens = length(params);
        channels = zeros(1, lens);
        for i=1:lens
            PVName = params{i};
            channels(i) = addChannel(PVName);
        end
        varargout{1} = channels;
 
    case 3  % mcaopen
        handles = cell2mat(channel_table.keys());
        counts = repmat({''}, 1, length(handles));
        for i=1:length(handles)
            channel = channel_table(handles(i));
            counts{i} = char(channel.getName());
        end
        varargout{1} = handles;
        varargout{2} = counts;
    
    case 5  % mcaclose
        for i=1:length(varargin)
            handle = varargin{i};
            channel = channel_table(handle);
            channel.close();
            channel_table.remove(handle);
        end

    case 10 % mcainfo
        
    case 11 % mcainfo handle
        
    case 12 % mcastate
        handles = cell2mat(channel_table.keys());
        counts = zeros(1, length(handles));
        for i=1:length(handles)
            channel = channel_table(handles(i));
            counts(i) = channel.isConnected();
        end
        varargout{1} = handles;
        varargout{2} = counts;
    
    case 13 % mcastate handle1, handle2
        handles = cell2mat(varargin);
        counts = zeros(1, length(handles));
        for i=1:length(handles)
            channel = channel_table(handles(i));
            counts(i) = channel.isConnected();
        end
        varargout{1} = counts;
        
    case 30 % mcapoll is not necessary
        
    case 40 % mcaenumstrings
        
    case 41 % mcaegu
        
    case 42 % mcaprec
        
    case 43 % mcatype
        
    case 50 % mcaget handle1, handle2, ...
        handles = cell2mat(varargin);
        for i=1:length(handles)
            channel = channel_table(handles(i));
            varargout{i} = channel.get();
        end
        
    case 51 % mcaget [handle1, handle2, ...]
    	handles = varargin{1};
        counts = zeros(1, length(handles));
        for i=1:length(handles)
            channel = channel_table(handles(i));
            counts(i) = channel.get(true);
        end
        varargout{1} = counts;
        
    case 60 % mcatime
        
    case 61 % mcaalarm
        
    case 70 % mcaput handle, value, handle, value ...
        if (mod(length(varargin), 2) ~=0 )
            error('Handles and values must match');
        end
        for i=1:2:length(varargin)
            handle = varargin{i};
            value = varargin{i+1};

            channel = channel_table(handle);
            channel.put(value);
        end
    case 80 % mcaput [hand1e1, handle2,...], [value1, value2, ...]
        handles = varargin{1};
        values = varargin{2};
        if (length(handles) ~= length(values))
            error('Handles and values must match')
        end
        for i=1:length(handles)
            handle = handles(1);
            value = values(1);
            
            channel = channel_table(handle);
            channel.putNoWait(value);            
        end
        
        
    case 100 % mcamon
        handle = varargin{1};
        channel = channel_table(handle);
        channel.setMonitored(true);
        
        varargout{1} = channel.isMonitored();
        
    case 200 % mcaclearmon
        handle = varargin{1};
        channel = channel_table(handle);
        channel.setMonitored(false);
        
    case 300 % mcacache
        handles = cell2mat(varargin);
        for i=1:length(handles)
            channel = channel_table(handles(i));
            varargout{i} = channel.get(false);
        end

    case 500    % MCAMON - get info on installed monitors.
        
    case 510    % MCAMONEVENTS - Event count for monitors
        handles = cell2mat(channel_table.keys());
        counts = zeros(1, length(handles));
        varargout{1} = handles;
        varargout{2} = counts;
        
    case 600    % MCAEXEC - Execute the command strings for the 
                %           channels in the monitor queue
        
    case 999    % MCAEXIT
        if channel_table
            delete(channel_table);
            channel_table = [];
        end
        context.close();
        
    case 1001   % Set connection timeout
    case 1002   % Set get timeout
    case 1003   % Set put timeout
    case 1004   % Reset timeout to defaults
    case 1000   % Set all timeout, connection/get/put
end

end

function handle = addChannel(PVName)
    global context
    global channel_table

    channel_desc = javaObjectEDT('ch.psi.jcae.ChannelDescriptor', 'double', PVName);
    channel = ch.psi.jcae.Channels.create(context, channel_desc);
    handle = channel.hashCode();
    channel_table(handle) = channel;
end

