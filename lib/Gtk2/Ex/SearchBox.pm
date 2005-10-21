package Gtk2::Ex::SearchBox;

our $VERSION = '0.01';

use warnings;
use strict;
use Gtk2 -init;
use Glib ':constants';
use Data::Dumper;
use Gtk2::Gdk::Keysyms;
use Gtk2::Ex::PopupWindow;

use constant OPERATOR_COLUMN => 0;
use constant MODEL____COLUMN => 1;
use constant NAME_____COLUMN => 2;

sub new {
	my ($class, $type, $operatorlist) = @_;
	my $self  = {};
	my $default_operatorlist = [
		'contains',
		'doesn\'t contain',
		'not equals',
		'equals',
	];
	$self->{operatorlist} = $operatorlist || $default_operatorlist;
	$self->{type} = $type || 'multiple';	
	bless ($self, $class);
	$self->{widget} = $self->_create_widget();
	return $self;
}

sub signal_connect {
	my ($self, $signal, $callback) = @_;
	$self->{signals}->{$signal} = $callback;
}

sub get_model {
	my ($self) = @_;
	return $self->{datamodel};
}

sub attach_popup_to {
	my ($self, $parent) = @_;
	my $popupwindow = Gtk2::Ex::PopupWindow->new($parent);
	$popupwindow->set_move_with_parent(TRUE);
	my $frame = Gtk2::Frame->new;
	$frame->add($self->{widget});
	$self->{popup} = $popupwindow;
	$popupwindow->{window}->add($frame);
	return $popupwindow;	
}

sub _create_widget {
	my ($self) = @_;

	my @column_types;
	$column_types[0] = 'Glib::String';
	$column_types[OPERATOR_COLUMN] = 'Glib::String';
	$column_types[MODEL____COLUMN] = 'Gtk2::ListStore';
	$column_types[NAME_____COLUMN] = 'Glib::String';

	my $table = Gtk2::Table->new(2,4,FALSE);
	my $operatorcombo = Gtk2::ComboBox->new_text;	
	my $entry = Gtk2::Entry->new;
	my $ok_button = Gtk2::Button->new_from_stock('gtk-ok');

	my $add_another_button = Gtk2::Button->new('_Add Pattern');
	
	my $treemodel = Gtk2::ListStore->new (@column_types);   
	my $treeview= Gtk2::TreeView->new($treemodel);
	my $scrolledwindow = Gtk2::ScrolledWindow->new;
	
	$self->{treeview}  = $treeview;
	$self->{treemodel} = $treemodel;
	$self->_add_combo;
	$self->_populate;
	$treeview->set_headers_visible(FALSE);
	$treeview->get_selection->set_mode('multiple');
	$treeview->signal_connect ('key-press-event' => 
		sub {
			my ($widget, $event) = @_;
			if ($event->keyval == $Gtk2::Gdk::Keysyms{'Delete'}) {
				my @paths = $treeview->get_selection->get_selected_rows;
				return if $#paths < 0;
				my @sel = map { $_->to_string } @paths;
				my $data = $self->{datamodel};
				foreach my $i (reverse sort @sel) {
					splice (@$data, $i, 1);
				}
				$self->{datamodel} = $data;
				$self->_populate;
				$self->_check_list_visibility();
				&{ $self->{signals}->{'changed'} } if $self->{signals}->{'changed'};
			}        		
		}
	);
	$operatorcombo->set_wrap_width(1);
	my $operatorlist = $self->{operatorlist};
	foreach my $x (@$operatorlist) {
		$operatorcombo->append_text($x);
	}
	$operatorcombo->set_active(0);
	$operatorcombo->signal_connect('realize' =>
		sub {
			$treeview->get_column(0)->set_min_width(
				$operatorcombo->size_request->width
			);
			$entry->grab_focus;
		}
	);
	$add_another_button->set_sensitive(FALSE);
	$self->_check_list_visibility();
	if ($self->{type} eq 'single') {
		$add_another_button->hide;
		$add_another_button->set_no_show_all(TRUE);	
	}
	if ($#{@{$self->{operatorlist}}} <= 0) {
		$operatorcombo->hide;
		$operatorcombo->set_no_show_all(TRUE);		
	}
	$add_another_button->signal_connect('clicked' => 
		sub {
			if ($entry->get_text) {
				my $data = $self->{datamodel};
				my %hash = map { $_->{field} => 1 } @$data;
				return if $hash{$entry->get_text};
				push @$data, {
					'field'    => $entry->get_text,
					'operator' => $operatorlist->[$operatorcombo->get_active],
				};
				$self->{datamodel} = $data;
				$self->_populate;
				$self->_check_list_visibility();
				$entry->set_text('');
				$entry->grab_focus;
				&{ $self->{signals}->{'changed'} } if $self->{signals}->{'changed'};
			}
		}
	);
	$ok_button->signal_connect('clicked' => 
		sub {
			&{ $self->{signals}->{'closed'} } if $self->{signals}->{'closed'};
		}
	);
	$entry->signal_connect( 'changed' => 
		sub {
			if ($entry->get_text) {
				$add_another_button->set_sensitive(TRUE);
			} else {
				$add_another_button->set_sensitive(FALSE);		
			}
		}
	);

	$scrolledwindow->set_policy('never', 'automatic');
	$scrolledwindow->add($treeview);
	$entry->set_activates_default(TRUE);

	$ok_button->signal_connect( 'realize' => 
		sub {
			$ok_button->set_flags ('can-default');
			$ok_button->grab_default;
		}
	);

	#$table->set_col_spacings(5);
	#$table->attach($operatorcombo     ,0,1,0,1, 'fill', 'fill', 0, 0);
	#$table->attach($entry             ,1,2,0,1, 'fill'  , 'fill', 0, 0);
	#$table->attach($ok_button         ,2,3,0,1, 'fill', 'fill', 0, 0);
	#$table->attach($add_another_button,3,4,0,1, 'fill', 'fill', 0, 0);
	#$table->attach($scrolledwindow    ,0,2,1,2, 'fill'  , 'expand', 0, 0);

	my $hbox1 = Gtk2::HBox->new (FALSE, 0);
	$hbox1->pack_start ($operatorcombo, FALSE, TRUE, 0); 	
	$hbox1->pack_start ($entry, TRUE, TRUE, 0); 	

	my $vbox1 = Gtk2::VBox->new (FALSE, 0);
	$vbox1->pack_start ($hbox1, FALSE, TRUE, 0); 	
	$vbox1->pack_start ($scrolledwindow, TRUE, TRUE, 0); 	

	my $hbox2 = Gtk2::HBox->new (FALSE, 0);
	$hbox2->pack_start ($ok_button, FALSE, TRUE, 0); 	
	$hbox2->pack_start ($add_another_button, FALSE, TRUE, 0); 	

	my $vbox2 = Gtk2::VBox->new (FALSE, 0);
	$vbox2->pack_start ($hbox2, FALSE, TRUE, 0); 	
	$vbox2->pack_start (Gtk2::Label->new, TRUE, TRUE, 0); 	

	my $hbox = Gtk2::HBox->new (FALSE, 0);
	$hbox->pack_start ($vbox1, TRUE, TRUE, 0); 	
	$hbox->pack_start ($vbox2, FALSE, TRUE, 0); 

	return $hbox;
}



sub _add_combo {
	my ($self) = @_;
	my $treeview  = $self->{treeview};
	my $treemodel = $self->{treemodel};
	
	my $combo_renderer = Gtk2::CellRendererCombo->new;
	$combo_renderer->set (
		text_column => 0, # col in combo model with text to display
		editable => TRUE, # without this, it's just a text renderer
	); 
	$combo_renderer->signal_connect (edited => 
		sub {
			my ($cell, $text_path, $new_text) = @_;
			$treemodel->set (
				$treemodel->get_iter_from_string($text_path),
				OPERATOR_COLUMN, 
				$new_text
			);
			# &{ $self->{signals}->{'changed'} } if $self->{signals}->{'changed'};
		}
	);
	$treeview->insert_column_with_attributes(
		-1, 'Operators', 
		$combo_renderer,
		text  => OPERATOR_COLUMN, 
		model => MODEL____COLUMN
	);
	$treeview->insert_column_with_attributes(
		-1, 'Fields', 
		Gtk2::CellRendererText->new, 
		text => NAME_____COLUMN
	);
}

sub _populate{
	my ($self) = @_;
	my $treeview  = $self->{treeview};
	my $treemodel = $self->{treemodel};
	my $data      = $self->{datamodel};
	my $i = 0;
	my $operatorlist = $self->{operatorlist};
	my %lookup_hash = map { $_ => $i++ } @$operatorlist;
	my $combomodel = Gtk2::ListStore->new('Glib::String');
	foreach my $key (@$operatorlist) {
		$combomodel->set($combomodel->append, 0, $key);
	}
	$treemodel->clear();
	foreach my $data (@$data) {
		$data->{operator} = $lookup_hash{$data->{operator}};
		$data->{operator} = $combomodel->get(
			$combomodel->iter_nth_child (undef, $data->{operator})
			, 0
		);
		$treemodel->set (
			$treemodel->append,
			NAME_____COLUMN, $data->{field},
			OPERATOR_COLUMN, $data->{operator},
			MODEL____COLUMN, $combomodel 
		);
	}
}

sub _check_list_visibility {
	my ($self) = @_;
	my $treeview  = $self->{treeview};
	my $data      = $self->{datamodel};
	if ($#{@$data} >= 0) {
		$treeview->set_sensitive(TRUE);		
		#$treeview->set_no_show_all(FALSE);	
		#$treeview->show;
	} else {
		$treeview->set_sensitive(FALSE);
		#$treeview->hide;
		#$treeview->set_no_show_all(TRUE);	
		#$window->set_focus($entry);
	}
}

1;

__END__


=head1 NAME

Gtk2::Ex::SearchBox - A simple widget for specifying a search pattern (or a list of
search patterns).

=head1 DESCRIPTION

A simple widget for specifying a search pattern (or a list of
search patterns).

=head1 SYNOPSIS

	my $searchbox = Gtk2::Ex::SearchBox->new;
	$window->add($searchbox->{widget});

=head1 METHODS

=head2 new;

=head2 set_model($model);

=head2 get_model;

=head2 attach_popup_to($parent);

=head2 signal_connect($signal, $callback);

See the SIGNALS section to see the supported signals.

=head1 SIGNALS

=head2 changed;

=head2 closed;

=head1 SEE ALSO

Gtk2::Ex::PopupWindow

=head1 COPYRIGHT & LICENSE

Copyright 2005 Ofey Aikon, All Rights Reserved.

This library is free software; you can redistribute it and/or modify it under
the terms of the GNU Library General Public License as published by the Free
Software Foundation; either version 2.1 of the License, or (at your option) any
later version.

This library is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE.  See the GNU Library General Public License for more
details.

You should have received a copy of the GNU Library General Public License along
with this library; if not, write to the Free Software Foundation, Inc., 59
Temple Place - Suite 330, Boston, MA  02111-1307  USA.

=cut