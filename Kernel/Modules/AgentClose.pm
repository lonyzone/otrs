# --
# AgentZoom.pm - to get a closer view
# Copyright (C) 2001 Martin Edenhofer <martin+code@otrs.org>
# --
# $Id: AgentClose.pm,v 1.3 2002-01-23 23:02:26 martin Exp $
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see http://www.gnu.org/licenses/gpl.txt.
# --

package Kernel::Modules::AgentClose;

use strict;
use Kernel::System::Article;

use vars qw($VERSION);
$VERSION = '$Revision: 1.3 $';
$VERSION =~ s/^.*:\s(\d+\.\d+)\s.*$/$1/;

# --
sub new {
    my $Type = shift;
    my %Param = @_;

    # allocate new hash for object    
    my $Self = {};
    bless ($Self, $Type);
    
    foreach (keys %Param) {
        $Self->{$_} = $Param{$_};
    }

    # check needed Opjects
    foreach ('ParamObject', 'DBObject', 'TicketObject', 'LayoutObject', 'LogObject', 'QueueObject', 'ConfigObject') {
        die "Got no $_!" if (!$Self->{$_});
    }

    return $Self;
}
# --
sub Run {
    my $Self = shift;
    my %Param = @_;
    my $Output;
    my $TicketID = $Self->{TicketID};
    my $QueueID = $Self->{QueueID};
    my $LockID = 2;
    my $UnLockID = 0;
    my $Subaction = $Self->{Subaction};
    my $NextScreen = $Self->{NextScreen} || '';
    my $BackScreen = $Self->{BackScreen} || '';
    my $UserID    = $Self->{UserID};
    my $UserLogin = $Self->{UserLogin};
    
    my $Tn = $Self->{TicketObject}->GetTNOfId(ID => $TicketID);
    
    if ($Subaction eq '' || !$Subaction) {
        # get next states
        my %NextStates = $Self->{DBObject}->GetTableData(
            Table => 'ticket_state',
            Valid => 0,
            What => 'id, name'
        );
        foreach (keys %NextStates) {
            if ($NextStates{$_} !~ /^close/i) {
                delete $NextStates{$_};
            }
        }
        # get possible notes
        my %NoteTypes = $Self->{DBObject}->GetTableData(
            Table => 'article_type',
            Valid => 1,
            What => 'id, name'
        );
        foreach (keys %NoteTypes) {
            if ($NoteTypes{$_} !~ /^note/i) {
                delete $NoteTypes{$_};
            }
        }

        # get lock state
        my $LockState = $Self->{TicketObject}->GetLockState(TicketID => $TicketID) || 0;
        if (!$LockState) {
            $Self->{TicketObject}->SetLock(
                TicketID => $TicketID,
                Lock => 'lock',
                UserID => $UserID
            );
            $Self->{TicketObject}->SetOwner(
                TicketID => $TicketID,
                UserID => $UserID,
                UserLogin => $UserLogin,
            );
        }
        # print form ...
        $Output .= $Self->{LayoutObject}->Header();
        $Output .= $Self->{LayoutObject}->AgentClose(
            TicketID => $TicketID,
            BackScreen => $Self->{BackScreen},
            NextScreen => $Self->{NextScreen},
            TicketNumber => $Tn,
            QueueID => $QueueID,
            Locked => $LockState,
            NextStatesStrg => \%NextStates,
            NoteTypesStrg => \%NoteTypes,
        );
        $Output .= $Self->{LayoutObject}->Footer();
    }
    elsif ($Subaction eq 'Store') {
        # store action
        my $StateID = $Self->{ParamObject}->GetParam(Param => 'CloseStateID');
        my $NoteID = $Self->{ParamObject}->GetParam(Param => 'CloseNoteID');
        my $Subject = $Self->{ParamObject}->GetParam(Param => 'Subject') || '';
        my $Text = $Self->{ParamObject}->GetParam(Param => 'Text');
        my $ArticleObject = Kernel::System::Article->new(
            DBObject => $Self->{DBObject},
            ConfigObject => $Self->{ConfigObject},
        );
        my $ArticleID = $ArticleObject->CreateArticleDB(
            TicketID => $TicketID,
            ArticleTypeID => $NoteID,
            SenderType => 'agent',
            From => $UserLogin,
            To => $UserLogin,
            Subject => $Subject,
            Body => $Text,
            CreateUserID => $UserID
        );
        $Self->{TicketObject}->SetState(
            UserID => $UserID,
            TicketID => $TicketID,
            ArticleID => $ArticleID,
            StateID => $StateID,
        );
        $Self->{TicketObject}->SetLock(
            UserID => $UserID,
            TicketID => $TicketID,
            Lock => 'unlock'
        );
        $Output .= $Self->{LayoutObject}->Redirect(OP => "&Action=$NextScreen&QueueID=$QueueID");
    }
    else {
        # error screen
        $Output .= $Self->{LayoutObject}->Header();
        $Output .= $Self->{LayoutObject}->Error(
            MSG => 'No Subaction!!',
            REASON => 'Please contact your admin'
        );
        $Self->{LogObject}->ErrorLog(
            MSG => 'No Subaction!!',
            REASON => 'Please contact your admin'
        );
        $Output .= $Self->{LayoutObject}->Footer();
    }
    return $Output;
}

1;
