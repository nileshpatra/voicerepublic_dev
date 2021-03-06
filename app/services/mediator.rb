#require 'resolv'

require File.expand_path(File.join(%w(.. .. .. lib services)), __FILE__)

require File.expand_path(File.join(%w(.. mediator dj_callback)), __FILE__)

# The Mediator's responsibility is to subscribe to relevant channels
# and transform events into human readable notifications and forward
# those to a notification channel.
#
# Messages in the `notifications` channel will be picked up an
# forwarded to some communication channel like Slack, IRC or Text
# Messages. Best practice is to use different channels for regocnized
# and yet unrecognized (generic/unformatted) messages.
#
class Mediator

  # a never complete list of boring domains
  BORING_DOMAINS = %w(
    aol.com aol.de att.net
    bluewin.ch btinternet.com
    comcast.net cox.com
    emailgo.de exemail.com.au
    fadingemails.com free.fr freenet.de
    gmail.com gmx.info gmx.ch gmx.org gmx.us gmx.de gmx.net gmx.at googlemail.com
    hotmail.de hotmail.com hotmail.co.uk hotmail.co.ul hotmail.cl.uk
    icloud.com
    yahoo.co.uk yahoo.com yahoo.de yahoo.fr yopmail.com
    live.com live.co.uk live.ca
    mail.com me.com msn.com mail.ru
    ncable.net.au ntlworld.com
    online.de outlook.com outlook.de
    posteo.de
    sbcglobal.net sezampro.rs sohu.com
    t-online.de talk21.com
    versanet.de
    web.de
    xs4all.nl
    yandex.com ymail.com
  )

  include Services::Subscriber  # provides `subscribe`
  include Services::Publisher   # provides `publish`
  include Services::LocalConfig # provides `config`
  include Services::AutoPublish # publishes the return value of handlers

  subscribe x: 'dj_callback', handler: DjCallback
  subscribe x: 'talk_transition'
  subscribe x: 'lifecycle_user'
  subscribe x: 'lifecycle_message'
  subscribe x: 'cdn_status'
  subscribe x: 'transaction_transition'


  def cdn_status(*args)
    args.shift['cdn_status'].each do |cdn|
      text = 'CDN: Failed to fetch resource %s error code %s' %
                                 [cdn['resource'], cdn['status']]
      publish x: 'notification', channel: 'voicerepublic_dev', text: text
    end
  end

  def talk_transition(*args)
    body = args.shift
    event = body['details']['event'] * '.'
    error = body['details']['talk']['error']
    error = error.split("\n")[0, 2].join("\n") unless error.nil?
    intros = {
      'created.pending.prepare'      => 'Has been uploaded',
      'created.prelive.prepare'      => 'Has been scheduled',
      'prelive.live.start_talk'      => 'Now live',
      'live.postlive.end_talk'       => 'Has come to end',
      'postlive.queued.enqueue'      => 'Has been queued for processing',
      'suspended.queued.enqueue'     => 'Suspended has been queued for reprocessing',
      'queued.processing.process'    => 'Started processing',
      'processing.archived.archive'  => 'Just archived recording',
      'pending.archived.archive'     => 'Just archived upload',
      'processing.suspended.suspend' => "Failed to process with '#{error}'",
      'suspended.archived.archive'   => 'Just archived suspended',
      'postlive.archived.archive'    => 'Just archived abandoned',
      'prelive.archived.archive'     => 'Just archived scheduled',
      'prelive.postlive.abandon'     => 'Has been abandoned'
    }
    intro = intros[event]
    intro ||= 'Don\'t know how to format talk event `%s` for' % event
    talk = body['details']['talk']
    user = body['details']['user']
    _talk = slack_link(talk['title'], talk['url'])
    _user = slack_link(user['name'], user['url'])

    { x: 'notification', text: "#{intro} (#{talk['id']}) #{_talk} by #{_user}" }
  end

  # NOTE trouble to refactor this into a submodule, since it needs
  # access to `config` and `publish`
  def transaction_transition(*args)
    body = args.shift
    details = body['details']
    event = body['event']
    type = details['type']

    # spread out to specififc methods
    method = ([type.underscore] + event) * '_'
    return send(method, body) if respond_to?(method)

    nil
    # TODO send unformatted message to a 'raw' channel
    # { x: notification, channel: config.slack.channel_raw, text: body.inspect }
  end

  def manual_transaction_processing_closed_close(body)
    details  = body['details']

    details['comment'] ||= '(none)'

    quantity = details['quantity'].to_i
    payment  = details['payment'].to_i

    movement = :unknown
    movement = :deduct if quantity < 0  and payment == 0
    movement = :undo   if quantity < 0  and payment < 0
    movement = :donate if quantity > 0  and payment == 0
    movement = :sale   if quantity > 0  and payment > 0
    movement = :track  if quantity == 0 and payment > 0
    movement = :noop   if quantity == 0 and payment == 0
    movement = :weird  if quantity < 0  and payment > 0
    movement = :weird  if quantity >= 0 and payment < 0

    template = {
      deduct: 'Admin %{admin} deducted %{quantity} credits from %{username} with comment: %{comment}',
      undo: 'Admin %{admin} undid a booking for %{username}, by deducting %{quantity} credits and giving EUR %{payment} back with comment: %{comment}',
      donate: 'Admin %{admin} donated %{quantity} credits to %{username} with comment: %{comment}',
      sale: 'Admin %{admin} sold %{quantity} credits for EUR %{payment} to %{username} with comment: %{comment}',
      track: 'Admin %{admin} tracked a sale of EUR %{payment} to %{username}, restrospectively with comment: %{comment}',
      noop: 'Admin %{admin} contemplated about the meaning of life with comment: %{comment}',
      weird: 'Admin %{admin} and %{username} seem to be in cahoots. Alert the authorities, fishy transaction going on with comment: %{comment}'
    }

    message = template[movement] % details

    { x: 'notification', text: message }
  end

  def purchase_transaction_processing_closed_close(body)
    user = body['user_name'] || 'Someone'
    product = body['purchase_product'] || 'something'
    price = body['purchase_amount'] || 'some amount'

    message = '%s purchased %s for %s. (%s)' %
              [user, product, price, body.inspect]

    { x: 'notification',
      channel: config.slack.revenue_channel,
      text: message }
  end

  def lifecycle_user(*args)
    body = args.shift
    event = body['event']
    attrs = body['attributes']

    name = [attrs['firstname'], attrs['lastname']] * ' '
    url = body['user_url']
    email = attrs['email']

    case event
    when 'create'

      #ip = attrs['current_sign_in_ip']
      #host_or_ip = resolv(ip)
      message = "%s just registered with %s" %
                [slack_link(name, url), email]

      domain = email.split('@').last
      domain = false if BORING_DOMAINS.include?(domain)
      message += ", check out http://" + domain if domain

      { x: 'notification', text: message }

    when 'update'
      return nil unless attrs['paying']
      credits = body['changes']['credits']
      return nil if credits.nil?
      old, new = credits
      return nil unless old > 2 and new < 3

      message = 'Follow up: %s (%s) dropped under 3 credits.' % [name, email]
      [{
         x: 'customer_relation',
         action: 'followup',
         email: email,
         name: name,
         text: message
       }, {
         x: 'notification',
         text: message
       }]
    else
      nil
    end
  end


  def lifecycle_message(*args)
    body = args.shift
    attrs = body['attributes']

    # message = "Someone has posted a message. (#{body.inspect})"

    user = slack_link(body['user_name'] || attrs['user_id'], body['user_url'])
    talk = slack_link(body['talk_title'] || attrs['talk_id'], body['talk_url'])

    message = "Message from %s in %s" %
              [ user, talk ]

    { x: 'notification',
      text: message,
      attachments: [ { text: attrs['content'] } ] }
  end

  def run
    publish x: 'notification', text: 'Mediator started.'
    super
  end

  private

  #def resolv(ip)
  #  Resolv.getname(ip)
  #rescue
  #  ip
  #end

  def slack_link(title, url)
    "<#{url}|#{title}>"
  end

end

# SERVICE Mediator
# dj_callback ->
# talk_transition ->
# lifecycle_user ->
# lifecycle_message ->
# transaction_transition ->
# -> notification
# -> techne
