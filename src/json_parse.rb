require 'json'

File.open("#{__dir__}/instance_lists.json") do |f|
    data = JSON.load(f)
    next if data['Reservations'].empty?
    data['Reservations'].map do |res|
        res['Instances'].map do |instance|
            p instance['InstanceId']
        end
    end
end
