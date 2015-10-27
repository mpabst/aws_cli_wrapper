require 'erb'
require 'tempfile'
require 'json'

class AwsCliWrapper < Struct.new(:binding)

  class Inner < Struct.new(:binding, :service)
    def initialize(binding, service)
      super(binding, _format_token(service))
    end

    def method_missing(meth, *args)
      _run(meth, *args)
    end

    def _erb(file)
      path = "#{file}.json.erb"
      if File.exists?(path)
        tmp = Tempfile.new(file.gsub('/', '_') + '.json')
        tmp.write(ERB.new(File.read(path)).result(binding))
        tmp.close # flush to disk
        tmp.path
      end
    end

    def _format_token(s)
      s.to_s.gsub(/[ _]/, '-')
    end

    def _run(_command, _opts = {})
      command = _format_token(_command)
      opts = _opts.inject({}){|o,(k,v)| o.update(_format_token(k) => v) }

      if file = opts.delete('json')
        path = ((tmp = erb(file)) ? tmp : file + '.json')
        opts['cli-input-json'] = 'file://' + path
      end

      sh = (
        ['aws', service, command] +
        opts.map{|(k,v)| "--#{k} '#{v}'" }
      ) * ' '
      puts sh

      out = %x{#{sh}}
      begin
        JSON.parse(out)
      rescue JSON::ParserError
        out
      end
    end
  end

  %w( opsworks ec2 elb rds elasticache s3api cloudfront ).each do |service|
    define_method(service) do |command = nil, opts = {}|
      i = Inner.new(binding, service)
      command ? i._run(command, opts) : i
    end
  end

end
