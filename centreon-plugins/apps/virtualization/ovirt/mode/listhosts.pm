#
# Copyright 2019 Centreon (http://www.centreon.com/)
#
# Centreon is a full-fledged industry-strength solution that meets
# the needs in IT infrastructure and application monitoring for
# service performance.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

package apps::virtualization::ovirt::mode::listhosts;

use base qw(centreon::plugins::mode);

use strict;
use warnings;

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options);
    bless $self, $class;
    
    $self->{version} = '1.0';
    $options{options}->add_options(arguments => {
        "filter-name:s" => { name => 'filter_name' },
    });

    return $self;
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::init(%options);
}

sub manage_selection {
    my ($self, %options) = @_;

    $self->{hosts} = $options{custom}->request_api(url_path => '/ovirt-engine/api/hosts');
}

sub run {
    my ($self, %options) = @_;

    $self->manage_selection(%options);
    foreach my $host (@{$self->{hosts}->{host}}) {
        next if (defined($self->{option_results}->{filter_name}) && $self->{option_results}->{filter_name} ne ''
            && $host->{name} !~ /$self->{option_results}->{filter_name}/);
        
        $self->{output}->output_add(long_msg => sprintf("[id = %s][name = %s]",
            $host->{id}, $host->{name}));
    }
    
    $self->{output}->output_add(severity => 'OK',
                                short_msg => 'List hosts:');
    $self->{output}->display(nolabel => 1, force_ignore_perfdata => 1, force_long_output => 1);
    $self->{output}->exit();
}

sub disco_format {
    my ($self, %options) = @_;
    
    $self->{output}->add_disco_format(elements => ['id', 'name']);
}

sub disco_show {
    my ($self, %options) = @_;

    $self->manage_selection(%options);
    foreach my $host (@{$self->{hosts}->{data_center}}) {
        $self->{output}->add_disco_entry(
            id => $host->{id},
            name => $host->{name},
        );
    }
}

1;

__END__

=head1 MODE

List hosts.

=over 8

=item B<--filter-name>

Filter host name (Can be a regexp).

=back

=cut
