#
# Copyright 2018 Centreon (http://www.centreon.com/)
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

package cloud::ibm::softlayer::mode::gettickets;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;

sub custom_ticket_output {
    my ($self, %options) = @_;
    
    my $msg = sprintf("Title: '%s', Group: '%s', Priority: %s, Create Date: %s", $self->{result_values}->{title}, 
        $self->{result_values}->{group}, $self->{result_values}->{priority}, $self->{result_values}->{createDate});
    return $msg;
}

sub custom_ticket_calc {
    my ($self, %options) = @_;
    
    $self->{result_values}->{id} = $options{new_datas}->{$self->{instance} . '_id'};
    $self->{result_values}->{title} = $options{new_datas}->{$self->{instance} . '_title'};
    $self->{result_values}->{priority} = $options{new_datas}->{$self->{instance} . '_priority'};
    $self->{result_values}->{createDate} = $options{new_datas}->{$self->{instance} . '_createDate'};
    $self->{result_values}->{group} = $options{new_datas}->{$self->{instance} . '_group'};
    return 0;
}

sub prefix_tickets_output {
    my ($self, %options) = @_;
    
    return "Ticket '" . $options{instance_value}->{id} . "' is open with ";
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'global', type => 0 },
        { name => 'tickets', type => 1, cb_prefix_output => 'prefix_tickets_output' },
    ];
    
    $self->{maps_counters}->{global} = [
        { label => 'open', set => {
                key_values => [ { name => 'open' } ],
                output_template => 'Number of open tickets : %d',
                perfdatas => [
                    { label => 'open_tickets', value => 'open_absolute', template => '%d',
                      min => 0 },
                ],
            }
        },
    ];
    $self->{maps_counters}->{tickets} = [
        { label => 'ticket', threshold => 0, set => {
                key_values => [ { name => 'id' }, { name => 'title' }, { name => 'priority' }, { name => 'createDate' },
                { name => 'group' } ],
                closure_custom_calc => $self->can('custom_ticket_calc'),
                closure_custom_output => $self->can('custom_ticket_output'),
                closure_custom_perfdata => sub { return 0; },
            }
        },
    ];
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options);
    bless $self, $class;
    
    $self->{version} = '1.0';
    $options{options}->add_options(arguments =>
                                {
                                    "ticket-group:s"    => { name => 'ticket_group' },
                                });

    return $self;
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::check_options(%options);
}

sub manage_selection {
    my ($self, %options) = @_;

    $self->{global}->{open} = 0;
    $self->{tickets} = {};

    my $group_id = '';
    my %groups_hash;
    my (undef, $groups) = $options{custom}->get_endpoint(service => 'SoftLayer_Ticket', method => 'getAllTicketGroups');
    foreach my $group (@{$groups->{'ns1:getAllTicketGroupsResponse'}->{'getAllTicketGroupsReturn'}->{'item'}}) {
        $groups_hash{$group->{id}->{content}} = $group->{name}->{content};

        if (defined($self->{option_results}->{ticket_group}) && $self->{option_results}->{ticket_group} ne '' && 
            $group->{name}->{content} =~ /$self->{option_results}->{ticket_group}/) {
            $group_id = $group->{id}->{content};
        }
    }

    if (defined($self->{option_results}->{ticket_group}) && $self->{option_results}->{ticket_group} ne '' && $group_id eq '') {
        $self->{output}->add_option_msg(short_msg => "Ticket group ID not found from API.");
        $self->{output}->option_exit();
    }

    my (undef, $tickets) = $options{custom}->get_endpoint(service => 'SoftLayer_Account', method => 'getOpenTickets');
    foreach my $ticket (@{$tickets->{'ns1:getOpenTicketsResponse'}->{'getOpenTicketsReturn'}->{'item'}}) {
        next if (defined($group_id) && $group_id ne '' && $ticket->{groupId}->{content} ne $group_id);

        $self->{tickets}->{$ticket->{id}->{content}} = {
            id => $ticket->{id}->{content},
            title => $ticket->{title}->{content},
            priority => $ticket->{priority}->{content},
            createDate => $ticket->{createDate}->{content},
            group => $groups_hash{$ticket->{groupId}->{content}},
        };

        $self->{global}->{open}++;
    }
}

1;

__END__

=head1 MODE

Check if there is open tickets

=over 8

=item B<--ticket-group>

Name of the ticket group (Can be a regexp).

=item B<--warning-open>

Threshold warning for open tickets.

=item B<--critical-open>

Threshold critical for open tickets.

=back

=cut
