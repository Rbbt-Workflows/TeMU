require 'rbbt-util'

module TeMU

  def self.models(key = self.to_s, *more)
    key
    key = key.to_s + "/*" if key.to_s == self.to_s and more.empty?
    key = key.to_s + "/" << more * "/" if more.any?

    if key == self.to_s
      Rbbt.share.models[key].glob_all("*").collect{|f| f.split("/")[-2..-1] }
    else
      alt_key =  self.to_s + "/" + key.to_s 
      (Rbbt.share.models[key].glob_all("*") + 
       Rbbt.share.models[alt_key].glob_all("*")).
      collect{|f| f.split("/")[-1] }.
      reject{|f| f.end_with? '.pickle' }
    end
  end

end

