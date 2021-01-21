# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: Edit suggested partitioning proposal and encrypt the partitions specified in test data.
#
# Maintainer: QA SLE YaST team <qa-sle-yast@suse.de>

use strict;
use warnings;
use parent 'y2_installbase';
use testapi;
use version_utils ':VERSION';
use scheduler 'get_test_suite_data';

sub run {
    my $test_data   = get_test_suite_data();
    my $partitioner = $testapi::distri->get_expert_partitioner();
    $partitioner->run_expert_partitioner('current');
    foreach my $disk (@{$test_data->{disks}}) {
        foreach my $partition (@{$disk->{partitions}}) {
            if ($partition->{encrypt_device}) {
                record_info("Encrypt $partition->{name}", "Encrypting $partition->{name} from disk $disk->{name}");
                $partitioner->edit_partition_encrypt({disk => $disk->{name}, partition => $partition->{name}});
            }
        }
    }
    $partitioner->accept_changes_and_press_next();
}

1;