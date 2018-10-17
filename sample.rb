require 'gnuplot'

Gnuplot.open do |gp|
  Gnuplot::SPlot.new(gp) do |plot|
    plot.set "isosamples 50,50"
    plot.set "pm3d at b"
    plot.data << Gnuplot::DataSet.new("sin(sqrt(x*x+y*y))/sqrt(x*x+y*y)")
  end
  gets
end
