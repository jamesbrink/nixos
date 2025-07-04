# N100 Network Configuration
# This module contains the network configuration for N100 cluster nodes

{
  # MAC addresses for N100 machines (from router DHCP configuration)
  n100-network = {
    nodes = {
      n100-01 = {
        mac = "e0:51:d8:12:ba:97";
        ip = "10.70.100.201";
      };
      n100-02 = {
        mac = "e0:51:d8:13:04:50";
        ip = "10.70.100.202";
      };
      n100-03 = {
        mac = "e0:51:d8:13:4e:91";
        ip = "10.70.100.203";
      };
      n100-04 = {
        mac = "e0:51:d8:15:46:4e";
        ip = "10.70.100.204";
      };
    };

    # Other important network devices
    infrastructure = {
      hal9000 = {
        mac = "a0:36:bc:e7:65:b8";
        ip = "10.70.100.206";
      };
      alienware = {
        mac = "10:65:30:6d:d0:e4";
        ip = "10.70.100.205";
      };
    };
  };
}
