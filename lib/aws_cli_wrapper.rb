require 'erb'
require 'tempfile'
require 'json'

module AwsCliWrapper
  def erb(file)
    path = "#{file}.json.erb"
    if File.exists?(path)
      tmp = Tempfile.new(file.gsub('/', '_') + '.json')
      tmp.write(ERB.new(File.read(path)).result)
      tmp.close # flush to disk
      tmp.path
    end
  end

  def run(_scope, _command, _opts = {})
    def fmt(s)
      s.to_s.gsub(/[ _]/, '-')
    end

    scope, command = *[_scope, _command].map{|p| fmt(p) }
    opts = _opts.inject({}){|o,(k,v)| o.update(fmt(k) => v) }

    if file = opts.delete('json')
      path = ((tmp = erb(file)) ? tmp : file + '.json')
      opts['cli-input-json'] = 'file://' + path
    end

    sh = (
      ['aws', scope, command] +
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

  %w( opsworks ec2 elb rds elasticache s3api cloudfront ).each do |svc|
    define_method(svc) do |cmd, opts = {}|
      run(cmd, opts)
    end
  end

  extend self
end
