<?php

namespace App\Enums;

/**
 * Décision n°3 du cahier des charges, laissée configurable
 * (réglage `follow_up.assignment_mode`).
 */
enum FollowUpAssignmentMode: string
{
    /** Le responsable de l'équipe qui a rencontré la personne est affecté. */
    case TeamLeader = 'team_leader';
    /** La personne qui enregistre assure le suivi. */
    case Creator = 'creator';
    /** Le contact n'est affecté à personne : l'équipe de suivi le répartit. */
    case CentralTeam = 'central_team';
}
