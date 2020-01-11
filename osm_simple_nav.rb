require_relative 'lib/graph_loader';
require_relative 'process_logger';

# Class representing simple navigation based on OpenStreetMap project
class OSMSimpleNav

  # Creates an instance of navigation. No input file is specified in this moment.
  def initialize
    # register
    @load_cmds_list = %w(--load --load-comp)
    @actions_list = %w(--export --show-nodes --midist)

    @usage_text = <<-END.gsub(/^ {6}/, '')
	  	Usage:\truby osm_simple_nav.rb <load_command> <input.IN> <action_command> <action_parameters> 
	  	 Load commands: 
	  	\t --load \t\t\t\t\t\t load map from file <input.IN>, IN can be ['DOT']
	  	 Action commands:
	  	\t --export <output.OUT> \t\t\t\t\t export graph into file <output.OUT>, OUT can be ['PDF','PNG','DOT']
	  	\t --show-nodes \t\t\t\t\t\t print all nodes of graph with their coordinates on the screen in format <node_id> : <lat>, <lon>
	  	\t --show-nodes <node_id1> <node_id2> <output.OUT> \t export graph into file <output.OUT> and highlight node1 and node2, OUT can be ['PDF','PNG','DOT']
	  	\t --show-nodes <lat1> <lon1> <lat2> <lon2> <output.OUT> \t export graph into file <output.OUT> and highlight nodes nearest the specified coordinates, OUT can be ['PDF','PNG','DOT']
	  	\t --midist <node_id1> <node_id2> <output.OUT> \t\t export graph into file <output.OUT> and highlight fastest path between node1 and node2, OUT can be ['PDF','PNG','DOT']
	  	\t --midist <lat1> <lon1> <lat2> <lon2> <output.OUT> \t export graph into file <output.OUT> and highlight fastest path between nodes nearest the specified coordinates, OUT can be ['PDF','PNG','DOT']
    END
  end

  # Prints text specifying its usage
  def usage
    puts @usage_text
  end

  # Command line handling
  def process_args
    # not enough parameters - at least load command, input file and action command must be given
    unless ARGV.length >= 3
      puts "Not enough parameters!"
      puts usage
      exit 1
    end

    # read load command, input file and action command
    @load_cmd = ARGV.shift
    unless @load_cmds_list.include?(@load_cmd)
      puts "Load command not registered!"
      puts usage
      exit 1
    end
    @map_file = ARGV.shift
    unless File.file?(@map_file)
      puts "File #{@map_file} does not exist!"
      puts usage
      exit 1
    end
    @operation = ARGV.shift
    unless @actions_list.include?(@operation)
      puts "Action command not registered!"
      puts usage
      exit 1
    end

    # possibly load other parameters of the action
    if @operation == '--export'
      if ARGV.length > 1
        wrong_params
      end
      # load output file
      @out_file = ARGV.shift
    elsif @operation == '--show-nodes'
      process_sub_operation
    elsif @operation == '--midist'
      process_sub_operation
    end

    @only_comp = false
    if @load_cmd == '--load-comp'
      @only_comp = true
    end
  end

  def process_sub_operation
    if ARGV.length == 0
      if @operation == '--midist'
        wrong_params
      end
      @sub_operation = 'console'
    elsif ARGV.length == 3
      @sub_operation = 'map-exact'
      @node_id_start = ARGV.shift
      @node_id_stop = ARGV.shift
      @out_file = ARGV.shift
    elsif ARGV.length == 5
      @sub_operation = 'map-nearest'
      @node_lat_start = ARGV.shift.to_f
      @node_lon_start = ARGV.shift.to_f
      @node_lat_stop = ARGV.shift.to_f
      @node_lon_stop = ARGV.shift.to_f
      @out_file = ARGV.shift
    else
      wrong_params
    end
  end

  def wrong_params
    puts "Wrong parameters for command #{@operation}!"
    puts usage
    exit 1
  end

  # Determine type of file given by +file_name+ as suffix.
  #
  # @return [String]
  def file_type(file_name)
    return file_name[file_name.rindex(".") + 1, file_name.size]
  end

  # Specify log name to be used to log processing information.
  def prepare_log
    ProcessLogger.construct('log/logfile.log')
  end

  # Load graph from OSM file. This methods loads graph and create +Graph+ as well as +VisualGraph+ instances.
  def load_graph
    graph_loader = GraphLoader.new(@map_file, @highway_attributes, @only_comp)
    @graph, @visual_graph = graph_loader.load_graph()
  end

  # Load graph from Graphviz file. This methods loads graph and create +Graph+ as well as +VisualGraph+ instances.
  def import_graph
    graph_loader = GraphLoader.new(@map_file, @highway_attributes)
    @graph, @visual_graph = graph_loader.load_graph_viz
  end

  def print_time(time)
    puts "Travel between chosen points will take approximately %0.2f minutes." % [time]
  end

  # Run navigation according to arguments from command line
  def run
    # prepare log and read command line arguments
    prepare_log
    process_args

    # load graph - action depends on last suffix
    #@highway_attributes = ['residential', 'motorway', 'trunk', 'primary', 'secondary', 'tertiary', 'unclassified']
    @highway_attributes = ['residential', 'motorway', 'trunk', 'primary', 'secondary', 'tertiary', 'unclassified', 'trunk_link']
    #@highway_attributes = ['residential']
    if file_type(@map_file) == "osm" or file_type(@map_file) == "xml" then
      load_graph
    elsif file_type(@map_file) == "dot" or file_type(@map_file) == "gv" then
      import_graph
    else
      puts "Input file type not recognized!"
      usage
    end

    # perform the operation
    case @operation
    when '--export'
      @visual_graph.export_graphviz(@out_file)
      return
    when '--show-nodes'
      case @sub_operation
      when 'console'
        @visual_graph.export_console
			when 'map-exact'
        @visual_graph.highlight_vertices([@node_id_start, @node_id_stop])
        @visual_graph.export_graphviz(@out_file)
      when 'map-nearest'
        id1 = @visual_graph.get_nearest_vertex(@node_lat_start, @node_lon_start)
        id2 = @visual_graph.get_nearest_vertex(@node_lat_stop, @node_lon_stop)
        @visual_graph.highlight_vertices([id1, id2])
        @visual_graph.export_graphviz(@out_file)
      end
    when '--midist'
      case @sub_operation
      when 'map-exact'
        path, time = @visual_graph.shortest_path_vertices(@node_id_start, @node_id_stop)
        @visual_graph.highlight_path(path)
        @visual_graph.export_graphviz(@out_file)
        print_time time
      when 'map-nearest'
        path, time = @visual_graph.shortest_path_positions(@node_lat_start, @node_lon_start, @node_lat_stop, @node_lon_stop)
        @visual_graph.highlight_path(path)
        id1 = @visual_graph.get_nearest_vertex(@node_lat_start, @node_lon_start)
        id2 = @visual_graph.get_nearest_vertex(@node_lat_stop, @node_lon_stop)
        @visual_graph.highlight_vertices([id1, id2])
        @visual_graph.export_graphviz(@out_file)
        print_time time
      end
    else
      usage
      exit 1
    end
  end
end

osm_simple_nav = OSMSimpleNav.new
osm_simple_nav.run
