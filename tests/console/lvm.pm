# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: it covers basic lvm commands
# pvcreate vgcreate lvcreate
# pvdisplay vgdisplay lvdisplay
# vgextend lvextend
# pvmove vgreduce
# pvremove vgremove lvremove
# Maintainer: Paolo Stivanin <pstivanin@suse.com>

use base "consoletest";
use base 'btrfs_test';
use strict;
use warnings;
use testapi;
use version_utils;
use utils 'zypper_call';

sub run {
    my ($self) = @_;

    select_console 'root-console';

    $self->set_playground_disk;
    my $disk = get_required_var('PLAYGROUNDDISK');

    zypper_call 'in lvm2';
    zypper_call 'in xfsprogs';

    # Create 3 partitions
    assert_script_run 'echo -e "g\nn\n\n\n+1G\nt\n8e\nn\n\n\n+1G\nt\n2\n8e\nn\n\n\n\nt\n\n8e\np\nw" | fdisk ' . $disk;
    assert_script_run 'lsblk';

    my $timeout = 180;

    # Create pv vg lv
    validate_script_output("pvcreate ${disk}1",             sub { m/successfully created/ }, $timeout);
    validate_script_output("pvdisplay",                     sub { m/\/dev\/vdb1/ },          $timeout);
    validate_script_output("vgcreate test ${disk}1",        sub { m/successfully created/ }, $timeout);
    validate_script_output("vgdisplay test",                sub { m/test/ },                 $timeout);
    validate_script_output("lvcreate -n one -L 1020M test", sub { m/created/ },              $timeout);
    validate_script_output("lvdisplay",                     sub { m/one/ },                  $timeout);

    # create a fs
    assert_script_run 'mkfs -t xfs /dev/test/one';
    assert_script_run 'mkdir /mnt/test_lvm';
    assert_script_run 'mount /dev/test/one /mnt/test_lvm';
    assert_script_run 'echo test > /mnt/test_lvm/test';
    assert_script_run 'cat /mnt/test_lvm/test|grep test';
    assert_script_run 'umount /mnt/test_lvm';

    # extend test volume group
    validate_script_output("pvcreate ${disk}2",      sub { m/successfully created/ },  $timeout);
    validate_script_output("pvdisplay",              sub { m/\/dev\/vdb2/ },           $timeout);
    validate_script_output("vgextend test ${disk}2", sub { m/successfully extended/ }, $timeout);

    # extend one logical volume with the new space
    validate_script_output("lvextend -L +1020M /dev/test/one", sub { m/successfully resized/ }, $timeout);
    assert_script_run 'mount /dev/test/one /mnt/test_lvm';
    assert_script_run 'cat /mnt/test_lvm/test | grep test';

    # extend the filesystem
    validate_script_output("xfs_growfs /mnt/test_lvm", sub { m/data blocks changed/ }, $timeout);
    validate_script_output("df -h /mnt/test_lvm",      sub { m/test/ },                $timeout);
    validate_script_output("cat /mnt/test_lvm/test",   sub { m/test/ });

    # move data from the original extend to the new one
    validate_script_output("pvcreate ${disk}3",      sub { m/successfully created/ },  $timeout);
    validate_script_output("vgextend test ${disk}3", sub { m/successfully extended/ }, $timeout);
    assert_script_run "pvmove ${disk}1 ${disk}3";

    # after moving data, remove the old extend with no data
    validate_script_output("vgreduce test ${disk}1", sub { m/Removed/ }, $timeout);

    # check the data just to be sure
    validate_script_output("cat /mnt/test_lvm/test", sub { m/test/ });

    # remove all
    assert_script_run 'umount /mnt/test_lvm';
    validate_script_output("lvremove -y /dev/test/one", sub { m/successfully removed/ }, $timeout);
    assert_script_run 'lvdisplay';
    validate_script_output("vgremove -y test", sub { m/successfully removed/ }, $timeout);
    assert_script_run 'vgdisplay';
    validate_script_output("pvremove -y ${disk}1 ${disk}2 ${disk}3", sub { m/successfully wiped/ }, $timeout);
    assert_script_run 'pvdisplay';
}

1;