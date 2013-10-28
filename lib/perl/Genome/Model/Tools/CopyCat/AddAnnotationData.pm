package Genome::Model::Tools::CopyCat::AddAnnotationData;

use strict;
use warnings;

use Carp;
use Genome;


class Genome::Model::Tools::CopyCat::AddAnnotationData {
    is => 'Command::V2',

    has => {
        'reference_sequence' => {
            is => 'Genome::Model::Build::ReferenceSequence',
            doc => 'Reference sequence the annotation data are derived from',
        },

        'version' => {
            is => 'Integer',
            doc => 'Version of these annotation data',
        },

        'data_directory' => {
            is => 'Path',
            doc => 'Directory to import into SoftwareResult',
        },

    },
};


sub execute {
    my $self = shift;

    $self->validate;
    my $sr = $self->create_software_result;
    $self->copy_data_to_software_result($sr);

    $self->status_message(
        "Successfully created CopyCat AnnotationData SoftwareResult");

    return 1;
}


sub validate {
    my $self = shift;

    unless (-d $self->data_directory) {
        confess 'data_directory was not a path to a directory';
    }
}


sub create_software_result {
    my $self = shift;

    return Genome::Model::Tools::CopyCat::AnnotationData->create(
        reference_sequence => $self->reference_sequence,
        version => $self->version,
    );
}


sub copy_data_to_software_result {
    my ($self, $sr) = @_;

    $self->_rsync_data_to_software_result($sr);
    $self->_set_permissions_on_software_result_allocation($sr);
}


sub _rsync_data_to_software_result {
    my ($self, $sr) = @_;

    eval {
        Genome::Sys->rsync_directory(
            source_directory => $self->data_directory,
            target_directory => $sr->annotation_data_path,
        );
    };
    if ($@) {
        my $error = $@;
        $self->_handle_data_failure($sr, $error);
    }
}


sub _set_permissions_on_software_result_allocation {
    my ($self, $sr) = @_;

    eval {
        $sr->allocation->set_permissions_read_only;
    };
    if ($@) {
        my $error = $@;
        $self->_handle_data_failure($sr, $error);
    }
}


sub _handle_data_failure {
    my ($self, $sr, $error) = @_;

    $self->_cleanup_software_result($sr);
    die $self->error_message(sprintf(
        "Failed to create CopyCat AnnotationData SoftwareResult: %s",
        $error));
}


sub _cleanup_software_result {
    my ($self, $sr) = @_;

    my $sr_id = $sr->id;

    eval {
        $sr->delete;
    };
    if ($@) {
        my $error = $@;
        $self->error_message(sprintf(
"Failed to delete AnnotationData SoftwareResult (%s) during cleanup: %s",
            $sr_id, $error));
    }
}


1;
