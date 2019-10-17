require_relative 'lib/graph_loader';
require_relative 'process_logger';

# Class representing simple navigation based on OpenStreetMap project
class OSMSimpleNav

	# Creates an instance of navigation. No input file is specified in this moment.
	def initialize
		# register
		@load_cmds_list = ['--load']
		@actions_list = ['--export']

		@usage_text = <<-END.gsub(/^ {6}/, '')
	  	Usage:\truby osm_simple_nav.rb <load_command> <input.IN> <action_command> <output.OUT> 
	  	\tLoad commands: 
	  	\t\t --load ... load map from file <input.IN>, IN can be ['DOT']
	  	\tAction commands: 
	  	\t\t --export ... export graph into file <output.OUT>, OUT can be ['PDF','PNG','DOT']
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
		  puts "Load command not registred!"
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
		  puts "Action command not registred!"
		  puts usage
		  exit 1			
		end

		# possibly load other parameters of the action
		if @operation == '--export'
		end

		# load output file
		@out_file = ARGV.shift
	end

	# Determine type of file given by +file_name+ as suffix.
	#
	# @return [String]
	def file_type(file_name)
		return file_name[file_name.rindex(".")+1,file_name.size]
	end

	# Specify log name to be used to log processing information.
	def prepare_log
		ProcessLogger.construct('log/logfile.log')
	end

	# Load graph from OSM file. This methods loads graph and create +Graph+ as well as +VisualGraph+ instances.
	def load_graph
		graph_loader = GraphLoader.new(@map_file, @highway_attributes)
		@graph, @visual_graph = graph_loader.load_graph()
	end

	# Load graph from Graphviz file. This methods loads graph and create +Graph+ as well as +VisualGraph+ instances.
	def import_graph
		graph_loader = GraphLoader.new(@map_file, @highway_attributes)
		@graph, @visual_graph = graph_loader.load_graph_viz
	end

	# Run navigation according to arguments from command line
	def run
		# prepare log and read command line arguments
		prepare_log
	    process_args

	    # load graph - action depends on last suffix
	    #@highway_attributes = ['residential', 'motorway', 'trunk', 'primary', 'secondary', 'tertiary', 'unclassified']
	    @highway_attributes = ['residential', 'motorway', 'trunk', 'primary', 'secondary', 'tertiary', 'unclassified']
	    #@highway_attributes = ['residential']
	    if file_type(@map_file) == "osm" or file_type(@map_file) == "xml" then
	    	puts "OSM not supported!"
	    	usage
	    	exit 1
	    	# load_graph
	    elsif file_type(@map_file) == "dot" or file_type(@map_file) == "gv" then
	    	import_graph
	    else
	    	puts "Imput file type not recognized!"
	    	usage
	    end
		
		# perform the operation
	    case @operation
	      when '--export'
	      	@visual_graph.export_graphviz(@out_file)
	      	return
	      else
	        usage
	        exit 1
	    end	
	end	
end

osm_simple_nav = OSMSimpleNav.new
osm_simple_nav.run
