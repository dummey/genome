package Genome::Disk::Command::Allocation::UnarchiveBase;

use Genome;
use JSON 'to_json';

use strict;
use warnings;

class Genome::Disk::Command::Allocation::UnarchiveBase {
    is => 'Command::V2',
    is_abstract => 1,
    has => {
        analysis_project => {
            is => 'Genome::Config::AnalysisProject',
            doc => 'The analysis project for which the data is being unarchived',
        },
        requestor => {
            is => 'Genome::Sys::User',
            is_optional => 1,
            doc => 'The user who is requesting the unarchive.',
        },
    },
};

sub execute {
    my $self = shift;

    unless ($self->requestor) {
        $self->requestor(Genome::Sys->current_user);
    }
    $self->status_message(sprintf("Unarchiving allocation(s) for Analysis Project %s at the request of %s.",
            $self->analysis_project, $self->requestor->name));

    return $self->_execute();
}

sub reason {
    my $self = shift;

    my %reason = (
        'analysis_project'=>$self->analysis_project->id,
        'requestor'=> $self->requestor->id
    );
    return to_json(\%reason);
}

1;
